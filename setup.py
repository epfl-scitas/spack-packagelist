from setuptools import setup

setup(
    name='SCITAS Environment',
    version='0.2',
    py_modules=['senv'],
    install_requires=[
        'Click',
        'PyYAML',
        'Jinja2',
        'GitPython',
    ],
    entry_points='''
        [console_scripts]
        senv=senv:senv
    '''
)
