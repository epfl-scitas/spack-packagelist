#!/usr/bin/env python

import argparse
import collections
import itertools
import yaml


class ConfigurationFileParser(object):
    """
    Parses a YAML configuration file and outputs a text file containing a list of triplets :

    <system-type> <compiler> <spec>

    each of which represents a package to be installed in a given configuration
    """
    def __init__(self, configuration):
        self.configuration = configuration
        self.axis = configuration['axis']
        # Check for compiler and architecture to be there
        if 'compiler' not in self.axis:
            raise RuntimeError('\'compiler\' must be set in the axis')
        if 'architecture' not in self.axis:
            raise RuntimeError('\'architecture\' must be set in the axis')
        # Create the right combinations of services
        self.combinations = collections.defaultdict(list)
        for name, specifications in configuration['combinations'].iteritems():
            # Check that all the axis are specified
            if not all(x in specifications for x in self.axis):
                raise RuntimeError('combination \'{0}\' doesn\'t specify all axis'.format(key))
            self.combinations[name] = self._build_combination(name, specifications)

        self.allowed_services = configuration.pop('allowed')
        self.current_services = {}
        # FIXME : self.current_services = {key: [] for key in self.allowed_services} when python will be upgraded
        for key in self.allowed_services:
            self.current_services[key] = []

        self.names = []
        self.packages = configuration.pop('packages')

    def _build_combination(self, name, specifications):
        # Each entry can be either a string or a list
        # All the lists MUST have the same length
        keys_that_are_list = {key: len(x) for key, x in specifications.items() if isinstance(x, list)}
        if len(keys_that_are_list) and len(set(keys_that_are_list.values())) != 1:
            raise RuntimeError('lists in combination \'{0}\' MUST have the same length'.format(name))
        # Explode all the lists in specifications if they are present
        exploded = []
        if not keys_that_are_list:
            exploded.append(specifications)
        else:
            exploded = self._explode_list_in_specification(keys_that_are_list, specifications)

        # Process each entry to have a list of unique combinations
        combinations = []

        for ii, x in enumerate(exploded):
            # Turn ':' separated values into lists
            intermediate = {key: value.split(':') for key, value in x.items()}
            # Turn a dict of lists into a list of list of tuples
            item = []
            for key, l in intermediate.items():
                item.append([(key, value) for value in l])
            # Now itertools.product to the rescue
            for entry in itertools.product(*item):
                combinations.append(dict(entry))
        return combinations

    def _explode_list_in_specification(self, keys_that_are_list, specifications):
        exploded = []
        others = {key: value for key, value in specifications.iteritems() if key not in keys_that_are_list}
        list_length = keys_that_are_list.values()[0]
        for idx in range(list_length):
            item = {}
            item.update(others)
            for key in keys_that_are_list:
                item[key] = specifications[key][idx]
            exploded.append(item)
        return exploded

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
