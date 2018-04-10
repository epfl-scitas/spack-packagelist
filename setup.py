from setuptools import setup

setup(
    name='SCITAS Environment',
    version='0.1',
    py_modules=['senv'],
    install_requires=[
        'Click',
        'PyYAML'
    ],
    entry_points='''
        [console_scripts]
        senv=senv:senv
    '''
)
