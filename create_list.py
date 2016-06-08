#!/usr/bin/env python

import argparse
import itertools
import yaml


class ConfigurationFileParser(object):
    """
    Parses a YAML configuration file and outputs a text file containing a list of triplets :

    <system-type> <compiler> <spec>

    each of which represents a package to be installed in a given configuration
    """
    def __init__(self, configuration):
        self.allowed_services = configuration.pop('allowed')
        self.current_services = {}
        # FIXME : self.current_services = {key: [] for key in self.allowed_services} when python will be upgraded
        for key in self.allowed_services:
            self.current_services[key] = []

        self.names = []
        self.packages = configuration.pop('packages')

    def _reduce_stack(self, key):
        reduction = set()
        for x in self.current_services[key]:
            reduction.update(x)
        # The set of compilers and systems must always be non-empty
        if key == 'compilers' and not reduction:
            raise RuntimeError('compilers set is empty')
        if key == 'systems' and not reduction:
            raise RuntimeError('systems set is empty')

        return reduction

    def _process(self, name, value):
        # Enter configuration for name
        self.names.append(name)
        header = '#\n' + '# ' + '::'.join(self.names) + '\n#'
        yield header
        services = set(value) & set(self.allowed_services)
        # Move services to the right stack
        for key in services:
            if value[key] == 'all':
                value[key] = self.allowed_services[key]
            self.current_services[key].append(value.pop(key))

        specs = value.pop('specs', tuple())

        # Construct the current set of providers
        compilers = self._reduce_stack('compilers')
        systems = self._reduce_stack('systems')

        other_services = []
        for key in self.allowed_services:
            if key in ('compilers', 'systems'):
                continue
            if self.current_services[key]:
                other_services.append(self._reduce_stack(key))

        # Handle specs at this level
        for compiler, system, base_spec in itertools.product(compilers, systems, specs):
            if other_services:
                for deps in itertools.product(*other_services):
                    spec = '^'.join(deps)
                    spec = '^'.join((base_spec, spec))
                    yield ' '.join((system, compiler, spec))
            else:
                yield ' '.join((system, compiler, base_spec))

        # Recurse for deeper nesting
        for key, item in value.iteritems():
            for x in self._process(key, item):
                yield x

        # Clean up the stack
        for key in services:
            self.current_services[key].pop()
        self.names.pop()

    def items(self):
        for name, value in self.packages.iteritems():
            for item in self._process(name, value):
                yield item


# Set up cli arguments
parser = argparse.ArgumentParser(
    description='Parses a yaml configuration file and creates a list of packages that needs to be installed'
)

# TODO : consider writing a schema for configuration files if they grow big enough to need it
parser.add_argument(
    '--input',
    help='input file (yaml configuration)',
    type=argparse.FileType(),
    required=True
)

parser.add_argument(
    '--output',
    help='output file',
    type=argparse.FileType('w'),
    required=True
)

args = parser.parse_args()
configuration = yaml.load(args.input)

lines = []
for item in ConfigurationFileParser(configuration).items():
    lines.append(item)
    print(item)

args.output.write('\n'.join(lines))
