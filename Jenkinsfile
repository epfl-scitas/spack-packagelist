pipeline {
    agent none

    // Adds timestamps to console logs
    options {
        timestamps()
    }

    stages {
        stage('Update production configuration') {
            // Prepare a release branch of Spack for deployment by:
            //
            // 1. Updating the tracked branch
            // 2. Copying the latest configuration files in place
            //

            agent {
                label 'fidis-login'
            }

            when {
                branch 'releases/*'
            }

            environment {
                SPACK_CHECKOUT_DIR = "/ssoft/spack/paien/spack.v1"
                SENV_VIRTUALENV_PATH = "/home/scitasbuild/paien/virtualenv/senv-py27"
            }

            steps {
                // Checkout Spack
                dir("${SPACK_CHECKOUT_DIR}") {
                    git url: "https://github.com/epfl-scitas/spack.git", branch: "${env.GIT_BRANCH}"
                }

                // Update the command line tool we use in production
                sh  'scripts/update_production_configuration.sh'
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

            agent {
                label 'fidis-login'
            }

            when {
                branch '*/paien/*'
            }

            environment {
                SPACK_PRODUCTION_DIR = "/ssoft/spack/paien/spack.v1"
            }

            steps {
                sh 'scripts/setup_pr_configuration.sh'
            }

            post {
                always {
                    archiveArtifacts artifacts:'*.txt'
                    stash name:'x86_E5v2_IntelIB', includes: 'to_be_installed.x86_E5v2_IntelIB.txt'
                    stash name:'x86_E5v2_Mellanox_GPU', includes: 'to_be_installed.x86_E5v2_Mellanox_GPU.txt'
                    stash name:'x86_E5v3_IntelIB', includes: 'to_be_installed.x86_E5v3_IntelIB.txt'
                    stash name:'x86_E5v4_Mellanox', includes: 'to_be_installed.x86_E5v4_Mellanox.txt'
                    stash name:'x86_S6g1_Mellanox', includes: 'to_be_installed.x86_S6g1_Mellanox.txt'
                }
            }
        }

        stage('Prepare production stack') {
            // Ensure that all the compilers that are needed in
            // production are in place.
            //
            // 1. Compute which compilers are needed using a
            //    python command
            // 2. Check if they are installed, and if not install them
            //

            when {
                branch 'releases/*'
            }

            environment {
                SPACK_CHECKOUT_DIR = "/ssoft/spack/paien/spack.v1"
                SENV_VIRTUALENV_PATH = "/home/scitasbuild/paien/virtualenv/senv-py27"
            }

            parallel {
                stage('x86_E5v2_IntelIB') {
                    agent {
                        label 'x86_E5v2_IntelIB'
                    }
                    steps {
                        sh  'scripts/install_production_compilers.sh'
                        sh  'scripts/install_production_stack.sh'
                    }
                    post {
                        always {
                            archiveArtifacts artifacts:'*.txt, *.xml'
                            junit testResults:'*.xml', allowEmptyResults:true
                        }
                    }
                }

                stage('x86_E5v2_Mellanox_GPU') {
                    agent {
                        label 'x86_E5v2_Mellanox_GPU'
                    }
                    steps {
                        sh  'scripts/install_production_compilers.sh'
                        sh  'scripts/install_production_stack.sh'
                    }
                    post {
                        always {
                            archiveArtifacts artifacts:'*.txt, *.xml'
                            junit testResults:'*.xml', allowEmptyResults:true
                        }
                    }
                }

                stage('x86_E5v3_IntelIB') {
                    agent {
                        label 'x86_E5v3_IntelIB'
                    }
                    steps {
                        sh  'scripts/install_production_compilers.sh'
                        sh  'scripts/install_production_stack.sh'
                    }
                    post {
                        always {
                            archiveArtifacts artifacts:'*.txt, *.xml'
                            junit testResults:'*.xml', allowEmptyResults:true
                        }
                    }
                }

                stage('x86_E5v4_Mellanox') {
                    agent {
                        label 'x86_E5v4_Mellanox'
                    }
                    steps {
                        sh  'scripts/install_production_compilers.sh'
                        sh  'scripts/install_production_stack.sh'
                    }
                    post {
                        always {
                            archiveArtifacts artifacts:'*.txt, *.xml'
                            junit testResults:'*.xml', allowEmptyResults:true
                        }
                    }
                }
                stage('x86_S6g1_Mellanox') {
                    agent {
                        label 'x86_S6g1_Mellanox'
                    }
                    steps {
                        sh  'scripts/install_production_compilers.sh'
                        sh  'scripts/install_production_stack.sh'
                    }
                    post {
                        always {
                            archiveArtifacts artifacts:'*.txt, *.xml'
                            junit testResults:'*.xml', allowEmptyResults:true
                        }
                    }
                }
            }
        }

        stage('Populate mirror') {
            // Compute what needs to be installed in production (software that
            // is part of the planned environment, but not installed yet). Then
            // retrieve all the resources (tarballs, etc.) that are needed
            // to build it in a mirror.

            // TODO: the agent below must have access to the network
            agent {
                label 'fidis-login'
            }

            when {
                branch 'releases/*'
            }

            environment {
                SPACK_CHECKOUT_DIR = "/ssoft/spack/paien/spack.v1"
                SENV_VIRTUALENV_PATH = "/home/scitasbuild/paien/virtualenv/senv-py27"
            }

            steps {
                sh 'scripts/populate_mirror.sh'
                stash name:'x86_E5v2_IntelIB', includes: 'to_be_installed.x86_E5v2_IntelIB.txt'
                stash name:'x86_E5v2_Mellanox_GPU', includes: 'to_be_installed.x86_E5v2_Mellanox_GPU.txt'
                stash name:'x86_E5v3_IntelIB', includes: 'to_be_installed.x86_E5v3_IntelIB.txt'
                stash name:'x86_E5v4_Mellanox', includes: 'to_be_installed.x86_E5v4_Mellanox.txt'
                stash name:'x86_S6g1_Mellanox', includes: 'to_be_installed.x86_S6g1_Mellanox.txt'
            }
            post {
                always {
                    archiveArtifacts artifacts:'*.txt, *.yaml'
                }
            }

        }

        stage('Test PR build') {
            // Compute what needs to be checked for this PR (software
            // that is in the current planned environment, but not on the
            // base release branch). Try to build it, and notify status on
            // github.

            agent any
            when {
                changeRequest target: 'releases/paien'
            }
            environment {
                SPACK_PRODUCTION_DIR = "/ssoft/spack/paien/spack.v1"
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

            parallel {
                stage('x86_E5v2_IntelIB') {
                    agent {
                        label 'x86_E5v2_IntelIB'
                    }

                    when {
                        branch 'releases/*'
                    }

                    environment {
                        SPACK_CHECKOUT_DIR = "/ssoft/spack/paien/spack.v1"
                        SENV_VIRTUALENV_PATH = "/home/scitasbuild/paien/virtualenv/senv-py27"
                    }

                    steps {
                        unstash name: 'x86_E5v2_IntelIB'
                        sh 'scripts/deploy_in_production.sh'
                        echo 'Notify failures somewhere'
                    }

                    post {
                        always {
                            archiveArtifacts artifacts:'*.txt, *.xml'
                            junit testResults:'*.xml', allowEmptyResults:true
                        }
                    }
                }
                stage('x86_E5v2_Mellanox_GPU') {
                    agent {
                        label 'x86_E5v2_Mellanox_GPU'
                    }

                    when {
                        branch 'releases/*'
                    }

                    environment {
                        SPACK_CHECKOUT_DIR = "/ssoft/spack/paien/spack.v1"
                        SENV_VIRTUALENV_PATH = "/home/scitasbuild/paien/virtualenv/senv-py27"
                    }

                    steps {
                        unstash name: 'x86_E5v2_Mellanox_GPU'
                        sh 'scripts/deploy_in_production.sh'
                        echo 'Notify failures somewhere'
                    }

                    post {
                        always {
                            archiveArtifacts artifacts:'*.txt, *.xml'
                            junit testResults:'*.xml', allowEmptyResults:true
                        }
                    }
                }
                stage('x86_E5v3_IntelIB') {
                    agent {
                        label 'x86_E5v3_IntelIB'
                    }

                    when {
                        branch 'releases/*'
                    }

                    environment {
                        SPACK_CHECKOUT_DIR = "/ssoft/spack/paien/spack.v1"
                        SENV_VIRTUALENV_PATH = "/home/scitasbuild/paien/virtualenv/senv-py27"
                    }

                    steps {
                        unstash name: 'x86_E5v3_IntelIB'
                        sh 'scripts/deploy_in_production.sh'
                        echo 'Notify failures somewhere'
                    }

                    post {
                        always {
                            archiveArtifacts artifacts:'*.txt, *.xml'
                            junit testResults:'*.xml', allowEmptyResults:true
                        }
                    }
                }
                stage('x86_E5v4_Mellanox') {
                    agent {
                        label 'x86_E5v4_Mellanox'
                    }

                    when {
                        branch 'releases/*'
                    }

                    environment {
                        SPACK_CHECKOUT_DIR = "/ssoft/spack/paien/spack.v1"
                        SENV_VIRTUALENV_PATH = "/home/scitasbuild/paien/virtualenv/senv-py27"
                    }

                    steps {
                        unstash name: 'x86_E5v4_Mellanox'
                        sh 'scripts/deploy_in_production.sh'
                        echo 'Notify failures somewhere'
                    }

                    post {
                        always {
                            archiveArtifacts artifacts:'*.txt, *.xml'
                            junit testResults:'*.xml', allowEmptyResults:true
                        }
                    }
                }

                stage('x86_S6g1_Mellanox') {
                    agent {
                        label 'x86_S6g1_Mellanox'
                    }

                    when {
                        branch 'releases/*'
                    }

                    environment {
                        SPACK_CHECKOUT_DIR = "/ssoft/spack/paien/spack.v1"
                        SENV_VIRTUALENV_PATH = "/home/scitasbuild/paien/virtualenv/senv-py27"
                    }

                    steps {
                        unstash name: 'x86_S6g1_Mellanox'
                        sh 'scripts/deploy_in_production.sh'
                        echo 'Notify failures somewhere'
                    }

                    post {
                        always {
                            archiveArtifacts artifacts:'*.txt, *.xml'
                            junit testResults:'*.xml', allowEmptyResults: true
                        }
                    }
                }
            }
        }
    }
}