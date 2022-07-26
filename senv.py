#!/usr/bin/env python3

# This script creates multiple spack environment files from a template
#
# Input sources:
#  - a Jinja2 template (spack.yaml.j2)
#  - a YAML file containing (meleze.yaml)
#     - the environments to create
#     - variables to be written per environment
#
# This file and the input live in the spack-site repo
#
from __future__ import print_function
import os
import re
import copy
import click
import datetime
import jinja2
import yaml
import json
import shutil
import git
import sys
import logging
from collections import MutableMapping
import subprocess
try:
    from subprocess import DEVNULL # py3k
except ImportError:
    DEVNULL = open(os.devnull, 'wb')

logger = logging.getLogger(__name__)

logging.basicConfig(format='%(asctime)s %(message)s', datefmt='%m/%d/%Y %I:%M:%S %p')

class CloneProgress(git.RemoteProgress):
    """ This class controls the progress of git operations.
        The `print_op_codes` variable helps on debug. If set
        to True, the progress will not be shown and instead
        the list of operation codes will be displayed. This
        is helpfull for deciding when to line break """
    print_op_codes = False
    op_codes_to_break_line = [10,65]
    last_op_code = [66]

    def _backspace(self, n):
        """ Erase the contents of the current line and place
            the typewriter at the begining of the line """
        sys.stdout.write((b'\x08' * n).decode())
        sys.stdout.write((b'\x20' * n).decode())
        sys.stdout.write((b'\x08' * n).decode())
        sys.stdout.flush()

    def _line_break_conditions(self, op_code):
        """ Set conditions for line break """
        line_break = False
        if op_code in self.op_codes_to_break_line:
            line_break = True
        return line_break

    def _line_break(self):
        """ Moves the typewriter to the next line """
        sys.stdout.write("\n")
        sys.stdout.flush()

    def _last_line(self, op_code):
        """ Inserts a line break for last line """
        if op_code in self.last_op_code:
            self._line_break()

    def _do_print_op_codes(self, op_code):
        """ Writes the current op_code. This can be
            usefull to developers if git API changes """
        sys.stdout.write(str(op_code) + ",")
        sys.stdout.flush()

    def update(self, op_code, cur_count, max_count=None, message=''):
        """ Displays git clone progress """
        if self.print_op_codes:
            self._do_print_op_codes(op_code)
        else:
            if self._line_break_conditions(op_code):
                self._line_break()
            self._backspace(100)
            sys.stdout.write(self._cur_line)
            sys.stdout.flush()
            self._last_line(op_code)

COMPILERS_COMPONENTS = {
    'intel': {
        'cc': 'icc',
        'c++': 'icpc',
        'f77': 'ifort',
        'f90': 'ifort',
        'prefix': '{0}/compilers_and_libraries_{1}/linux/'
    },
    'oneapi': {
        'cc': 'icx',
        'c++': 'icpx',
        'f77': 'ifx',
        'f90': 'ifx',
        'prefix': '{0}/compiler/{1}/linux/'
    },
    'gcc': {
        'cc': 'gcc',
        'c++': 'g++',
        'f77': 'gfortran',
        'f90': 'gfortran'
    },
    'clang': {
        'cc': 'clang',
        'c++': 'clang++',
        'f77': 'gfortran',
        'f90': 'gfortran'
    },
    'nvhpc': {
        'cc': 'nvc',
        'c++': 'nvc++',
        'f77': 'nvfortran',
        'f90': 'nvfortran',
        'prefix': '{0}/Linux_x86_64/{1}/compilers'
    }}

def _absolute_path(value, prefix=None):
    if os.path.isabs(value):
        return value
    if prefix is None:
        return os.path.abspath(value)
    if isinstance(prefix, list):
        prefix.append(value)
        return os.path.join(*prefix)
    return os.path.join(prefix, value)

def _filter_variant(value):
    variant = re.compile('([ +~][^ %+~@]+)*([ ^%][^ ^%]+)*')
    if isinstance(value, str):
        return variant.sub("", value).strip()
    return [ variant.sub("", v).strip() for v in value ]

def _version(value):
    filtered_value = _filter_variant(value)
    logger.debug("Trying to extract version of \'{}\' [{}]".format(
        filtered_value, value))
    version_re = re.compile(r"@([^+~\^@]+)")
    match = version_re.search(filtered_value)
    if match:
        logger.debug("Found version \'{}\' for {}".format(
            match.group(1), filtered_value))
        return match.group(1)
    return None

# Custom filter method
def _regex_replace(s, find, replace):
    """A non-optimal implementation of a regex filter"""
    ns = re.sub(find, replace, s)
    return ns

def _cuda_variant(environment, arch=True,
                  extra_off='', extra_on='',
                  stack='stable',
                  dep=False):
    if 'gpu' not in environment or environment['gpu'] != 'nvidia':
        return '~cuda{}'.format(extra_off)

    variant = "+cuda"
    if arch:
        variant = '{0} cuda_arch={1}'.format(
            variant,
            environment[stack]['cuda']['arch'].replace('sm_', '')
        )
        variant = "{0} {1}".format(variant, extra_on)
    if dep:
        variant = '{0} ^{1}'.format(
            variant,
            environment[stack]['cuda']['package'])

    return variant

def _hip_variant(environment, arch=True,
                  extra_off='', extra_on='',
                  stack='stable',
                  dep=False):
    if 'gpu' not in environment or environment['gpu'] != 'amd':
        return '~hip{}'.format(extra_off)

    variant = '+hip{}'.format(extra_on)
    if arch:
        variant = '{0} amd_gpu_arch={1}'.format(
            variant,
            environment[stack]['rocm']['arch']
        )

    return variant

def _filter_compiler_name(value):
    def _filter_name(value):
        if 'llvm' in value:
            return value.replace('llvm', 'clang')
        if 'intel-oneapi-compilers' in value:
            return value.replace('intel-oneapi-compilers', 'oneapi')
        return value

    if isinstance(value, list):
        return [ _filter_name(entry) for entry in value ]
    return _filter_name(value)

class SpackEnvs(object):
    def __init__(self, configuration, prefix=None, override={}):
        self.configuration = configuration
        self.environments = self.configuration.pop('environments')

        info_message='This file was created by magic at {0}'.format(
            datetime.datetime.now().strftime("%x %X"))

        self.customisation = dict()
        self.customisation['environment'] = \
            self.configuration['default_environment']
        self.customisation["info_message"] = info_message
        self.customisation["warning"] = 'DO NOT EDIT THIS FILE DIRECTLY'
        self.override = override
        if 'spack_root' in override:
            self.configuration['spack_root'] = override['spack_root']

        for k, v in self.configuration.items():
            self.customisation[k] = v

        self.prefix = prefix
        if prefix is None:
            self.prefix = self.configuration['spack_root']

        self.in_pr = (self.prefix != self.configuration['spack_root'])
        self.customisation['prefix'] = self.prefix
        self.customisation['in_pr'] = self.in_pr

        if self.in_pr:
            self.customisation['mirrors']['pr_local'] = os.path.join(prefix, 'pr-mirror')

        if 'stack_release' in self.configuration and 'stack_version' in self.configuration:
            self.spack_source_root = os.path.join(
                self.prefix,
                self.configuration['stack_release'],
                'spack.{0}'.format(self.configuration['stack_version']))
            self.spack_install_root = os.path.join(
                self.prefix,
                self.configuration['stack_release'],
                self.configuration['stack_version'])
        else:
            self.spack_source_root = os.path.join(self.prefix, 'spack')
            self.spack_install_root = os.path.join(self.prefix, 'spack')

        self.spack_environment_root = os.path.join(
            self.spack_source_root,
            "var", "spack", "environments")

        # Creating Jinja2 environment
        self.spack_env = jinja2.Environment(
            loader=jinja2.FileSystemLoader('./'),
            trim_blocks=True, lstrip_blocks=True,
            extensions=[],
            undefined=jinja2.DebugUndefined
        )

        # Registering custom filters
        self.spack_env.filters['exists'] = os.path.exists
        self.spack_env.filters['list_if_not'] = \
            lambda x: x if isinstance(x, list) else [x]
        self.spack_env.filters['filter_variant'] = _filter_variant
        self.spack_env.filters['absolute_path'] = _absolute_path
        self.spack_env.filters['regex_replace'] = _regex_replace
        self.spack_env.filters['filter_compiler_name'] = _filter_compiler_name
        self.spack_env.filters['compiler_component'] = self._compiler_component
        self.spack_env.filters['full_compiler_name'] = self._compiler_name
        self.spack_env.filters['spack_path'] = self._spack_path
        self.spack_env.filters['version'] = _version
        self.spack_env.globals['cuda_variant'] = _cuda_variant
        self.spack_env.globals['hip_variant'] = _hip_variant


    def _create_jinja_environment(self, template_path=None):
        if template_path is None:
            template_path = os.path.join('templates', 'common', 'spack.yaml.j2')
        return self.spack_env.get_template(template_path)

    def _dict_merge(self, d1, d2):
        '''
        Update two dicts of dicts recursively,
        if either mapping has leaves that are non-dicts,
        the second's leaf overwrites the first's.
        '''
        for k, v in d1.items(): # in Python 2, use .iteritems()!
            if k in d2:
                # this next check is the only difference!
                if all(isinstance(e, MutableMapping) for e in (v, d2[k])):
                    d2[k] = self._dict_merge(v, d2[k])
                # we could further check types and merge as appropriate here.
        d3 = d1.copy()
        d3.update(d2)
        return d3

    # get a cache for a given operation
    def _get_cache(self, type_):
        class cache(object):
            def __init__(self, type_, config):
                
                self.cache_file = os.path.expanduser('~/.{0}{1}_{2}_cache.yaml'.format(
                    config['stack_release'],
                    '.{0}'.format(config['stack_version']) if 'stack_version' in config else '',
                    type_))

                try:
                    with open(self.cache_file, 'r') as fh:
                        self.cache = yaml.load(fh, Loader=yaml.FullLoader)
                except IOError:
                    self.cache = None
                    pass

            def save(self):
                with open(self.cache_file, 'w') as fh:
                    yaml.dump(self.cache, fh)

        return cache(type_, self.configuration)

    # get the environment dict overriding the configurations
    # if there are environment specific ones
    def _get_env_customisation(self, environment):
        if environment not in self.environments and environment is not None:
            raise RuntimeError(
                'The environment {0} is not defined.'
                ' Valid environments are {1}'.format(environment,
                                                     self.list_envs(all=True)))
        customisation = copy.copy(self.customisation)

        customisation["environment"]['name'] = environment
        if environment is None:
            customisation["environment"]['name'] = 'None'

        # create a dictionary for each environment
        env = customisation['environment']
        if environment in self.configuration:
            customisation['environment'] = self._dict_merge(
                customisation['environment'],
                self.configuration[environment])

        if self.override:
            customisation['environment'] = self._dict_merge(
                customisation['environment'],
                self.override
            )

        # adds the compiler prefixes if they do not exists
        env = customisation['environment']
        for _type in env['stack_types']:
            if _type not in env:
                continue

            for compiler in env[_type]:
                stack = env[_type][compiler]
                if 'compiler' not in stack or 'compiler_prefix' in stack:
                    continue
                
                spec_compiler = self._compiler_name(
                    stack, env, stack_type=_type)

                spack_path = self._compiler_component(compiler, "prefix", env,
                                                      stack_type=_type)

                if spack_path is not None:
                    env[_type][compiler]['compiler_prefix'] = spack_path

        logger.debug(
            "Customisation for env {}: {}".format(
                environment,
                json.dumps(customisation['environment'])))

        return customisation

    def _compiler_name(self, compiler_stack, environment, stack_type=None):
        compiler_ = copy.copy(compiler_stack['compiler'])

        stack = None
        if stack_type is not None:
            stack = environment[stack_type]

        nvptx_re = re.compile('.*\+(nvptx|cuda)')
        if stack is not None and nvptx_re.match(compiler_) and 'cuda' in stack:
            compiler_ = '{0} ^{1}'.format(compiler_, stack['cuda']['package'])

        if '%' in compiler_:
            return compiler_

        core_compiler = environment['core_compiler']
        if 'core_compiler' in compiler_stack:
            core_compiler = compiler_stack['core_compiler'] 

        return '{0} %{1}'.format(compiler_, core_compiler)

    def _run_spack(self, *args, **kwargs):
        no_wait = kwargs.pop('no_wait', False)
        environment = kwargs.pop('environment', None)
        options = { 'stdout': subprocess.PIPE,
                    'stderr': subprocess.PIPE }
        if environment is not None:
            options['env'] = {
                'SPACK_ENV': os.path.join(
                self.spack_environment_root,
                environment)
            }

        command = [os.path.join(self.spack_source_root, 'bin', 'spack')]
        command.extend(args)

        logger.debug("Running command: {0} (with env {1})".format(
            ' '.join(command), options['env'] if 'env' in options else {}))
        
        spack = subprocess.Popen(command, **options)
        stdout, stderr = spack.communicate()
        logger.debug("Stdout: {0}".format(stdout.decode('utf-8')))
        logger.debug("Stderr: {0}".format(stderr.decode('utf-8')))
        return stdout.decode('ascii').split('\n'), stderr, spack

    def _spack_path(self, value, environment=None):
        logger.debug('Searching path of \'{}\''.format(value))
        cache = self._get_cache('compilers')
        if cache.cache is None:
            cache.cache = {}

        if value in cache.cache:
            logger.debug("Path found in cache {}".format(cache.cache[value]))
            return cache.cache[value]
        
        stdout, stderr, comm = self._run_spack(
            'location', '--install-dir', value,
            environment=environment)

        path_re = re.compile('.*(({0}|{1}).*)$'.format(
            self.spack_install_root,
            _absolute_path(self.configuration['spack_external'],
                           prefix=self.configuration['spack_root'])))

        for line in stdout:
            match = path_re.match(line)
            if match:
                spack_path = match.group(1)
                logger.debug("Path found match {}".format(spack_path))
                cache.cache[value] = spack_path
                cache.save()
                return spack_path

        logger.info("No path found for {}".format(value))
        return None

    def compilers(self, environment, stack_type=None, all=False):
        compilers = []
        customisation = self._get_env_customisation(environment)
        if stack_type is not None:
            stack_types = [stack_type]
        else:
            stack_types = customisation['environment']['stack_types']
        environments = [customisation['environment']]
        if all:
            environments.append(self._get_env_customisation(None)['environment'])

        for env in environments:
            for _type in stack_types:
                for name, stack in env[_type].items():
                    if 'compiler' in stack and name in env['compilers']:
                        compilers.append(self._compiler_name(
                            stack, env, stack_type=_type))
                        if 'core_compiler' in stack:
                            compilers.append(
                                "{} %{}".format(
                                    _filter_variant(
                                        stack['core_compiler'])
                                    , env['core_compiler']))

        return list(set(compilers))

    def status(self):
        if self.in_pr:
             print("Running in a PR:\n - in prefix: {0}\n - in upstream: {1}".format(
                self.prefix, self.configuration['spack_root']))
        else:
            print("Running in deploy:\n - in prefix: {0}".format(self.prefix))

    def list_envs(self, cloud=None, all=False):
        if all:
            return self.environments
        envs = []
        for env_name in self.environments:
            logger.debug(
                "Getting env custimuization for env {}".format(env_name))
            customisation = self._get_env_customisation(env_name)
            env = customisation['environment']
            if ((cloud is None and 'cloud' not in env)
                 or (cloud is not None and ('cloud' in env and env['cloud'] == cloud))):
                envs.append(env_name)
        return envs

    def write_envs(self, bootstrap=False):
        for environment in self.environments:
            self.write_env(environment, bootstrap)

    def write_env(self, environment, bootstrap=False):
        spack_yaml_root = os.path.join(self.spack_environment_root,
                                       environment)
        print('Creating evironment {0}  in {1}'.format(environment,
                                                       spack_yaml_root))

        spack_env_template = self._create_jinja_environment()

        if not os.path.isdir(spack_yaml_root):
            raise RuntimeError(
                '{0} does not exists, please first'
                ' run spack env create {1}'.format(spack_yaml_root, environment)
            )

        customisation = self._get_env_customisation(environment)
        customisation['environment']['bootstrap'] = bootstrap
        with open(os.path.join(spack_yaml_root, 'spack.yaml'), 'w+') as f:
            f.write(spack_env_template.render(customisation))

    def spack_release(self):
        print(self.configuration['spack_release'])

    def spack_checkout_dir(self):
        print(self.spack_source_root)

    def spack_external_dir(self):
        print(_absolute_path(self.configuration['spack_external'],
                             prefix=self.configuration['spack_root']))

    def spack_checkout(self):
        if not os.path.exists(self.spack_source_root):
            git.Repo.clone_from('https://github.com/spack/spack.git',
                                self.spack_source_root,
                                branch=self.configuration['spack_release'],
                                progress=CloneProgress())
        else:
            git_repo = git.Repo(self.spack_source_root)
            local_branch = self.configuration['spack_release']
            git_repo.remotes.origin.fetch()

            commit = git_repo.commit(local_branch)
            if commit != git_repo.head.commit:
                git_repo.remotes.origin.pull(local_branch)


    def spack_checkout_extra_repos(self):
        if 'extra_repos' not in self.configuration:
            return

        for repo in self.configuration['extra_repos']:
            info = self.configuration['extra_repos'][repo]
            repo_path = _absolute_path(
                info['path'],
                prefix=[self.prefix,
                        self.configuration['stack_release'],
                        'external_repos'])

            options={ 'progress': CloneProgress() }
            if os.path.exists(repo_path):
                git_repo = git.Repo(repo_path)
                git_repo.remotes.origin.pull(**options)
            else:
                if 'tag' in info:
                    options['branch'] = info['tag']
                git_repo = git.Repo.clone_from(
                    info['repo'], repo_path, **options)
                if self.in_pr and 'GIT_BRANCH' in os.environ:
                    remote_branch = os.environ['GIT_BRANCH']
                    local_branch = remote_branch.replace('origin/', '')
                    for ref in git_repo.remotes.origin.refs:
                        if ref.name == remote_branch:
                            print('Changing default branch fo repo ' +
                                  '\"{}\" from {} to {}'.format(
                                      repo,
                                      git_repo.head.reference.name,
                                      local_branch))
                            new_ref = git_repo.create_head(local_branch, ref)
                            new_ref.set_tracking_branch(ref)
                            new_ref.checkout()
                            break

    def list_extra_repositories(self):
        repositories = []
        for item in self.configuration['extra_repos']:
            repo = self.configuration['extra_repos'][item]
            repo['name'] = item
            repo['path'] = _absolute_path(
                repo['path'],
                prefix=[self.configuration['spack_root'],
                        self.configuration['stack_release'],
                        'external_repos'])
            repositories.append(repo)
        print(yaml.dump(repositories))

    def install_spack_default_configuration(self):
        jinja_file_re = re.compile('(.*\.ya?ml)\.j2$')
        spack_config_path = os.path.join(self.spack_source_root, 'etc', 'spack')
        customisation = self._get_env_customisation(None)
        for _file in os.listdir('./configuration'):
            m = jinja_file_re.match(_file)
            template_path = os.path.join('./configuration', _file)
            if  m is not None:
                spack_env_template = self._create_jinja_environment(
                    template_path)
                with open(os.path.join(
                        spack_config_path, m.group(1)), 'w') as fh:
                    fh.write(spack_env_template.render(customisation))
            else:
                shutil.copyfile(
                    template_path,
                    os.path.join(spack_config_path, _file))

    def intel_compilers_configuration(self, environment):
        customisation = self._get_env_customisation(environment)
        env = customisation['environment']
        jinja_file_re = re.compile('((.*)\.cfg)\.j2$')
        for _type in env['stack_types']:
            dict_ = env[_type]
            dict_['stack_release'] = self.configuration['stack_release']
            dict_['stack_version'] = self.configuration['stack_version']
            for _compiler_name in ['intel', 'oneapi']:
                if _compiler_name not in env['compilers']:
                    continue

                if _compiler_name not in dict_:
                    continue

                logger.debug(
                    'Checking configuration files for {}'.format(
                        _compiler_name))

                intel_config_path = self._compiler_component(
                    _filter_compiler_name(_compiler_name),
                    'bindir', env, stack_type=_type)
                if not isinstance(intel_config_path, list):
                    intel_config_path = [intel_config_path]


                if 'core_compiler' in dict_[_compiler_name]:
                    core_compiler_prefix = \
                        self._spack_path(dict_[_compiler_name]['core_compiler'])
                    dict_[_compiler_name]['core_compiler_prefix'] = \
                        core_compiler_prefix

                _external_path = './external/{}/config'.format(_compiler_name)
                for _file in os.listdir(_external_path):
                    m = jinja_file_re.match(_file)
                    if not m:
                        continue
                    template_path = os.path.join(
                        _external_path,
                        _file)
                    spack_env_template = self._create_jinja_environment(
                        template_path)

                    for _path in intel_config_path:
                        compiler_file = os.path.join(_path, m.group(2))
                        logger.debug('Checking if {} is a valid compiler'.format(compiler_file))
                        if not os.path.exists(compiler_file):
                            continue

                        config_file = os.path.join(_path, m.group(1))
                        with open(config_file, 'w') as fh:
                            fh.write(spack_env_template.render(dict_))
                            logger.debug('Writing file {} with config {}'.format(config_file, dict_))

    def spack_list_python(self, env, stack_type=None, installed_only=False):
        spack_config_path = os.path.join(self.spack_source_root, 'etc', 'spack')
        customisation = self._get_env_customisation(env)
        template_path = os.path.join('./templates/',
                                     self.configuration['site'],
                                     self.configuration['stack_release'])
        specs = []
        python_activated = {}
        for ver in [2, 3]:
            python_package_list = os.path.join(
                template_path,
                'python{}_activated.yaml.j2'.format('2' if ver == 2 else ''))
            if not  os.path.exists(python_package_list):
                continue
            
            python_activated[ver] = yaml.load(
                self._create_jinja_environment(
                    python_package_list
                ).render(customisation),
                Loader=yaml.FullLoader)
            
            if python_activated[ver] is None:
                python_activated[ver] = [] 

            logger.debug(
                'List of packages to activate for python {}: {}'.format(
                    ver, python_activated[ver]))

        if stack_type is not None:
            stack_types = [stack_type]
        else:
            stack_types = customisation['environment']['stack_types']

        installed_pkg_re = re.compile('[0-9a-z]* (.*?)@.*')

        for stack_type_ in stack_types:
            for compiler in customisation['environment'][stack_type_]:
                stack = customisation['environment'][stack_type_][compiler]
                if 'compiler' not in stack:
                    continue

                logger.debug(
                    'List of packages to activate for stack {}'.format(
                        stack))

                for ver in [2, 3]:
                    spec = {
                        'python_version': customisation['environment']['python'][ver],
                        'python_variants': customisation['environment']['python']['variant'][ver],
                        'compiler': _filter_variant(stack['compiler']),
                        'arch': '',
                    }
                    arch = None
                    if 'arch' in customisation['environment']:
                        arch = customisation['environment']['arch']
                    else:
                        if 'arch' in stack:
                            arch = stack['arch']
                        else:
                            stdout, stderr, comm = self._run_spack(
                                'arch'.format(**spec),
                                environment=env)
                            spec['arch'] = ' arch={}'.format(
                                stdout[0].strip())

                    if  arch is not None:
                        spec['arch'] = ' arch=linux-{}-{}'.format(
                            re.sub('([a-z]+[0-9]+)(\.[0-9]+)+',
                                   '\\1',
                                   customisation['environment']['os']),
                            arch)

                    python_spec = 'python@{python_version} {python_variants} %{compiler}{arch}'.format(**spec)
                    logger.debug(
                        'Python spec to consider {}'.format(
                            python_spec))

                    list_installed = []
                    if installed_only:
                        stdout, stderr, comm = self._run_spack(
                            'dependents', '--installed',
                            python_spec,
                            environment=env)

                        for line in stdout:
                            match = installed_pkg_re.match(line.decode('ascii'))
                            if match:
                                list_installed.append(match.group(1))

                    for package in python_activated[ver]:
                        if installed_only and package not in list_installed:
                            continue

                        specs.append('{} ^{}'.format(package, python_spec))
        
        return specs            

    def activate_specs(self, environment, stack_type=None):
        specs = self.spack_list_python(environment, stack_type,
                                       installed_only=True)

        print("List of packages to activate:")
        for spec in specs:
            print(" - {}".format(spec))
        
        cache = self._get_cache('activated')
        if cache.cache is None:
            cache.cache = []

        for spec in specs:
            print("== Trying to activate {} ==".format(spec))
            if spec in cache.cache:
                print (' + ==> {0} activated [cache]'.format(spec))
                continue

            stdout, stderr, comm = self._run_spack('activate', spec, environment=environment)
            for line in stdout:
                print(' + {}'.format(line.decode('ascii')))

            if comm.returncode is None:
                spack_.wait()

            if comm.returncode == 0:
                print(" = Adding {} to cache".format(spec))
                cache.cache.append(spec)
        cache.save()

    def get_environment_entry(self, environment, entry):
        path = entry.split('.')
        customisation = self._get_env_customisation(environment)
        node = customisation
        for level in range(len(path) - 1):
            node = node[path[level]]

        if path[-1] in node:
            result = node[path[-1]]
            if not isinstance(result, str):
                print(yaml.dump(result))
            else:
                print(result)
        else:
            print('{0} was not specified in configuration'.format(entry))


    def _compiler_component(self, value, component,
                            environment, stack_type=None, prefix=None):
        """Get the specified component of a compiler defined as a name and a stack"""
        logger.debug(
            'Compiler component {} for compiler {} [stack_type={}, prefix={}]'.format(
                component, value, stack_type, prefix))

        _components = COMPILERS_COMPONENTS[value]
        bindir = None
        libdir = None
        incdir = None
        
        if stack_type is not None:
            stack = environment[stack_type][value]
        else:
            stack = {}

        compiler_spec = value
        if stack:
            compiler_spec = self._compiler_name(stack,
                                                environment,
                                                stack_type=stack_type)
            logger.debug("Compiler spec: {}".format(compiler_spec))

        if prefix is None:
            if 'compiler_prefix' not in stack:
                prefix = self._spack_path(compiler_spec)
                stack['compiler_prefix'] = prefix
            else:
                prefix = stack['compiler_prefix']

        if component == 'is_installed':
            logger.debug(
                "Is {} installed ? {}".format(
                    compiler_spec,
                    bool(prefix)))
            
            return bool(prefix)

        if prefix is None:
            logger.warning(
                "No prefix found for {},"
                " this coupiler must not be installed on this machine".format(
                    compiler_spec))
            return None

        if component == 'prefix':
            return prefix

        if value == 'intel':
            #logger.debug("INTEL PREFIX {}".format(prefix))

            if 'external' not in stack or not stack['external']:
                prefix = _components['prefix'].format(
                    stack['compiler_prefix'], stack['suite_version'])
            bindir = [os.path.join(prefix, 'bin/intel64'),
                      os.path.join(prefix, 'bin')]
            libdir = [os.path.join(prefix, 'compiler/lib/intel64_lin')]
            #logger.debug("INTEL BINDIR {}".format(bindir))
        elif value == 'oneapi':
            #logger.debug("INTEL PREFIX {}".format(prefix))
            if 'external' not in stack or not stack['external']:
                prefix = _components['prefix'].format(
                    stack['compiler_prefix'], _version(compiler_spec))

            bindir = os.path.join(prefix, 'bin')
            libdir = os.path.join(prefix, 'compiler/lib/intel64')
            incdir = os.path.join(prefix, 'compiler/include')
            #logger.debug("INTEL BINDIR {}".format(bindir))
        elif value == "nvhpc":
            prefix = _components['prefix'].format(
                stack['compiler_prefix'], _version(compiler_spec))
        elif value == 'clang':
            core_compiler_prefix = self._spack_path(stack['core_compiler'])
            cc_libdir = os.path.join(core_compiler_prefix, 'lib64')

            core_compiler = _regex_replace(
                _filter_variant(stack['core_compiler']), '[@+~^][.0-9]*', '')
            if component in ['f77', 'f90']:
                return self._compiler_component(core_compiler, component,
                                           environment,
                                           prefix=core_compiler_prefix)
            libdir = [cc_libdir]
        else:
            libdir = os.path.join(prefix, 'lib64')

        # default bindir and libdir
        if bindir is None:
            bindir = os.path.join(prefix, 'bin')
        if libdir is None:
            libdir = os.path.join(prefix, 'lib')
        if incdir is None:
            incdir = os.path.join(prefix, 'include')

        if component == 'libdir':
            return libdir
        elif component == 'bindir':
            return bindir
        elif component == 'incdir':
            return incdir
        elif component == 'spec':
            return compiler_spec

        if isinstance(bindir, list):
            for _path in bindir:
                _path = os.path.join(_path, _components[component])
                if os.path.exists(_path):
                    return _path

        return os.path.join(bindir, _components[component])

@click.group()
@click.option(
    '--input', default='humagne.yaml', type=click.File('r'),
    help='YAML file containing the specification for a production environment')
@click.option('--prefix', default=None,
              help='Prefix of the whole installation')
@click.option('--debug', default=False, is_flag=True)
@click.option('--override', default='{}')
@click.pass_context
def senv(ctxt, input, prefix, debug, override):
    """This command helps with common tasks needed in the SCITAS-EPFL
    continuous integration pipeline"""
    ctxt.input = input
    ctxt.override = json.loads(override)
    ctxt.configuration = yaml.load(input, Loader=yaml.FullLoader)
    ctxt.prefix = prefix
    if debug:
        logger.setLevel(logging.DEBUG)
    
@senv.command()
@click.pass_context
def status(ctxt):
    spack_envs = SpackEnvs(ctxt.parent.configuration,
                           prefix=ctxt.parent.prefix,
                           override=ctxt.parent.override)
    spack_envs.status();

@senv.command()
@click.option('--cloud', default=None)
@click.option('--all', default=False, is_flag=True)
@click.pass_context
def list_envs(ctxt, cloud, all):
    spack_envs = SpackEnvs(ctxt.parent.configuration,
                           prefix=ctxt.parent.prefix,
                           override=ctxt.parent.override)
    for env in spack_envs.list_envs(cloud=cloud, all=all):
        print('{}'.format(env))

@senv.command()
@click.option('--env', help='Environment to list the compiler for',
              default=None, required=False)
@click.option('--stack-type', help='Stack type: stable, bleeding_edge',
              default=None, required=False)
@click.option('--all', default=False, is_flag=True)
@click.pass_context
def list_compilers(ctxt, env, stack_type, all):
    spack_envs = SpackEnvs(ctxt.parent.configuration,
                           prefix=ctxt.parent.prefix,
                           override=ctxt.parent.override)
    compilers = spack_envs.compilers(env, stack_type, all)
    for compiler in compilers:
        print('{}'.format(compiler))

@senv.command()
@click.option('--env', help='Environment to create')
@click.option('--bootstrap',
              help='Create temporay environments to bootstrap',
              is_flag=True)
@click.pass_context
def create_env(ctxt, env, bootstrap):
    spack_envs = SpackEnvs(ctxt.parent.configuration,
                           prefix=ctxt.parent.prefix,
                           override=ctxt.parent.override)
    spack_envs.write_env(env, bootstrap=bootstrap)

@senv.command()
@click.option('--bootstrap',
              help='Create temporay environments to bootstrap',
              is_flag=True)
@click.pass_context
def create_envs(ctxt, bootstrap):
    spack_envs = SpackEnvs(ctxt.parent.configuration,
                           prefix=ctxt.parent.prefix,
                           override=ctxt.parent.override)
    spack_envs.write_envs(bootstrap=bootstrap)

@senv.command()
@click.pass_context
def spack_release(ctxt):
    spack_envs = SpackEnvs(ctxt.parent.configuration,
                           prefix=ctxt.parent.prefix,
                           override=ctxt.parent.override)
    spack_envs.spack_release()

@senv.command()
@click.pass_context
def spack_checkout_dir(ctxt):
    spack_envs = SpackEnvs(ctxt.parent.configuration,
                           prefix=ctxt.parent.prefix,
                           override=ctxt.parent.override)
    spack_envs.spack_checkout_dir()

@senv.command()
@click.pass_context
def spack_external_dir(ctxt):
    spack_envs = SpackEnvs(ctxt.parent.configuration,
                           prefix=ctxt.parent.prefix,
                           override=ctxt.parent.override)
    spack_envs.spack_external_dir()

@senv.command()
@click.pass_context
def list_extra_repositories(ctxt):
    spack_envs = SpackEnvs(ctxt.parent.configuration,
                           prefix=ctxt.parent.prefix,
                           override=ctxt.parent.override)
    spack_envs.list_extra_repositories()

@senv.command()
@click.pass_context
def install_spack_default_configuration(ctxt):
    spack_envs = SpackEnvs(ctxt.parent.configuration,
                           prefix=ctxt.parent.prefix,
                           override=ctxt.parent.override)
    spack_envs.install_spack_default_configuration()

@senv.command()
@click.option('--env', help='Environment to list the compiler for')
@click.pass_context
def intel_compilers_configuration(ctxt, env):
    spack_envs = SpackEnvs(ctxt.parent.configuration,
                           prefix=ctxt.parent.prefix,
                           override=ctxt.parent.override)
    spack_envs.intel_compilers_configuration(env)

@senv.command()
@click.pass_context
def spack_checkout(ctxt):
    spack_envs = SpackEnvs(ctxt.parent.configuration,
                           prefix=ctxt.parent.prefix,
                           override=ctxt.parent.override)
    spack_envs.spack_checkout()

@senv.command()
@click.pass_context
def spack_checkout_extra_repos(ctxt):
    spack_envs = SpackEnvs(ctxt.parent.configuration,
                           prefix=ctxt.parent.prefix,
                           override=ctxt.parent.override)
    spack_envs.spack_checkout_extra_repos()

@senv.command()
@click.option('--env', help='Environment to list the compiler for')
@click.option('--stack-type', help='Stack type: stable, bleeding_edge',
              default=None, required=False)
@click.pass_context
def list_spec_to_activate(ctxt, env, stack_type):
    spack_envs = SpackEnvs(ctxt.parent.configuration,
                           prefix=ctxt.parent.prefix,
                           override=ctxt.parent.override)
    specs = spack_envs.spack_list_python(env, stack_type, installed_only=True)
    for spec in specs:
        print(spec)


@senv.command()
@click.option('--env', help='Environment to list the compiler for')
@click.option('--stack-type', help='Stack type: stable, bleeding_edge',
              default=None, required=False)
@click.pass_context
def activate_specs(ctxt, env, stack_type):
    spack_envs = SpackEnvs(ctxt.parent.configuration,
                           prefix=ctxt.parent.prefix,
                           override=ctxt.parent.override)
    spack_envs.activate_specs(env, stack_type)

@senv.command()
@click.argument('entry', nargs=1)
@click.option('--env', help='Environment to list the compiler for',
              default=None)
@click.pass_context
def get_environment_entry(ctxt, entry, env):
    spack_envs = SpackEnvs(ctxt.parent.configuration,
                           prefix=ctxt.parent.prefix,
                           override=ctxt.parent.override)
    spack_envs.get_environment_entry(env, entry)
