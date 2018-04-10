pipeline {
    agent none

    // Adds timestamps to console logs
    options {
        timestamps()
    }

    stages {
        stage('Update production environment') {
            // Prepare a release branch of Spack for deployment by:
            //
            // 1. Updating the tracked branch
            // 2. Copying the latest configuration files in place
            //

            // TODO: the agent below must have access to the network
            agent any
            when {
                branch 'releases/*'
            }
            environment {
                // TODO: move to the right /ssoft space
                SPACK_CHECKOUT_DIR = '/tmp/spack'
            }
            steps {
                dir("${SPACK_CHECKOUT_DIR}") {
                    git url: "https://github.com/epfl-scitas/spack.git", branch: "${env.GIT_BRANCH}"
                }

                // Copy configuration files into the correct place
                // TODO: use declarative syntax? fileOperations?
                sh '''
                   cp -v configuration/* ${SPACK_CHECKOUT_DIR}/etc/spack/
                   # TODO: remove this comment in case
                   # cp -v -r external/* /ssoft/spack/external/
                   '''
            }
        }

        stage('Set-up test environment for a PR') {
            // Prepare a temporary work space for a PR branch:
            //
            // 1. Checkout the branch somewhere
            // 2. Copying the latest configuration files in place
            // 3. Link references to production compilers
            // 4. Compute which specs need to be tested and where
            //    they need to be tested
            //

            // TODO: the agent below must have access to the network
            agent any
            when {
                changeRequest target: 'releases/paien'
            }
            environment {
                // TODO: temporary space, but must be on a shared folder (will be reused later)
                SPACK_CHECKOUT_DIR = '/tmp/spack'
            }
            steps {
                dir("${SPACK_CHECKOUT_DIR}") {
                    git url: "https://github.com/epfl-scitas/spack.git", branch: "${env.GIT_BRANCH}"
                }

                // Copy configuration files into the correct place
                // TODO: use declarative syntax? fileOperations?
                sh '''#!/bin/bash
                   cp -v configuration/* ${SPACK_CHECKOUT_DIR}/etc/spack/
                   # TODO: remove this comment in case
                   # cp -v -r external/* /ssoft/spack/external/
                   '''

                echo "Linking production compilers"
                echo '''Computing specs that needs to be tested (How?).
                     Leave a file per architecture, archive it.
                     '''
            }
        }

        stage('Prepare production compilers') {
            // Ensure that all the compilers that are needed in
            // production are in place.
            //
            // 1. Compute which compilers are needed using a
            //    python command
            // 2. Check if they are installed, and if not install them
            //

            agent any
            when {
                branch 'releases/*'
            }
            environment {
                // TODO: move to the right /ssoft space
                SPACK_CHECKOUT_DIR = '/tmp/spack'
            }
            // TODO: here we need parallel stages on different agents
            // TODO: each of which is spawned on a node
            steps {
                dir("${SPACK_CHECKOUT_DIR}") {
                    sh '''#!/bin/bash
                       ls
                       # . share/spack/setup-env.sh
                       # spack --version
                       '''
                    echo "Computing which compilers are needed on this node"
                    echo '''If they are note there yet:
                         1. Build and install them
                         2. Register them as compilers
                         '''
                }
            }
        }

        stage('Populate mirror') {
            // Compute what needs to be installed in production (software that
            // is part of the planned environment, but not installed yet). Then
            // retrieve all the resources (tarballs, etc.) that are needed
            // to build it in a mirror.

            // TODO: the agent below must have access to the network
            agent any
            when {
                branch 'releases/*'
            }
            environment {
                // TODO: move to the right /ssoft space
                SPACK_CHECKOUT_DIR = '/tmp/spack'
            }
            steps {
                echo 'Computing what needs to be installed, producing one file per target.'
                echo 'Populating mirrors'
            }
        }

        stage('Test PR build') {
            // Compute what needs to be checked for this PR (software
            // that is in the current planned environment, but not on the
            // base release branch). Try to build it, and notify status on
            // github.

            // FIXME: do we need to populate a mirror also for this case?
            // FIXME: How are we going to fetch the artifacts?
            agent any
            when {
                changeRequest target: 'releases/paien'
            }
            environment {
                // TODO: move to the right /ssoft space
                SPACK_CHECKOUT_DIR = '/tmp/spack'
            }

            // TODO: here we need parallel stages on different agents
            // TODO: each of which is spawned on a node
            steps {
                echo 'Install software modified in this PR, output junit.xml, archive it'
                echo 'Notify results on github'
            }
        }

        stage('Deploy software') {
            // Deploy the software that is planned to be in the environment,
            // but not yet installed. Notify failures.

            agent any
            when {
                branch 'releases/*'
            }
            environment {
                // TODO: move to the right /ssoft space
                SPACK_CHECKOUT_DIR = '/tmp/spack'
            }
            // TODO: here we need parallel stages on different agents
            // TODO: each of which is spawned on a node
            steps {
                echo 'Install software that is planned, but not yet in production. Output junit.xml'
                echo 'Notify failures somewhere'
            }
        }

    }
}