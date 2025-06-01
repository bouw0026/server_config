# ~/server_config/setup.py
from setuptools import setup, find_packages

setup(
    name='server_config',
    version='1.0.0',
    author='Lucas Bouwman',
    author_email='bouw0026@algonquinlive.com',
    description='A comprehensive module for configuring Linux servers',
    long_description=open('README.md').read(),
    long_description_content_type='text/markdown',
    url='https://github.com/bouw0026/server_config.git',
    packages=find_packages(),
    install_requires=[
        # List your dependencies from requirements.txt here
        'PyYAML>=6.0',
        'python-iptables>=1.0.0', 
        'dnspython>=2.2.1',
    ],
    classifiers=[
        'Programming Language :: Python :: 3',
        'License :: OSI Approved :: MIT License', 
        'Operating System :: POSIX :: Linux',
        'Topic :: System :: Systems Administration',
    ],
    python_requires='>=3.6', 
    # Define command-line entry points for server_app.py and gui.py
    entry_points={
        'console_scripts': [
            'server-config-cli=server_config.server_app:main',
            'server-config-gui=server_config.gui:main',
        ],
    },
    include_package_data=True, 
)