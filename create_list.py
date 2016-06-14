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
        self.packages = configuration['packages']

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

    def _process(self, name, value):
        # Enter configuration for name
        header = '#\n' + '# ' + name + '\n#'
        yield header

        ##
        # Construct the targets
        ##

        # Merge
        targets = []
        for target_name in value['target_matrix']:
            targets.extend(self.combinations[target_name])
        # Filter
        for key, allowed in value.get('target_filter', {}).items():
            targets = [x for x in targets if x[key] in allowed]
        # Reduce
        requires = value['requires']
        for ii, x in enumerate(targets):
            item = targets[ii]
            targets[ii] = {key: item[key] for key in requires}
        # Make a dict hashable on the fly
        targets = [dict(y) for y in set([tuple(x.items()) for x in targets])]

        # Construct the right values
        specs = value.get('specs', tuple())
        for item in targets:
            compiler = item.pop('compiler')
            architecture = item.pop('architecture')
            for base_spec in specs:
                parts = [base_spec]
                parts.extend([v for v in item.values()])
                spec = '^'.join(parts)
                yield ' '.join((architecture, compiler, spec))

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
