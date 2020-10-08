@Library('xmos_jenkins_shared_library@v0.14.2') _
getApproval()

pipeline {
  agent {
    label 'x86_64&&macOS'
  }
  environment {
    REPO = 'lib_dfu'
    VIEW = getViewName(REPO)
  }
  options {
    skipDefaultCheckout()
  }
  stages {
    stage('Get view') {
      steps {
        xcorePrepareSandbox("${VIEW}", "${REPO}")
      }
    }
    stage('Library checks') {
      steps {
        xcoreLibraryChecks("${REPO}")
      }
    }
    stage('xCORE builds') {
      steps {
        dir("${REPO}") {
          dir("${REPO}") {
            runXdoc('doc')
          }
        }
      }
    }
    stage('Build host app') {
      steps {
        dir("${REPO}/host/suffix_generator") {
          sh "cmake ."
          sh "make"
          stash name: "host-app", includes: "bin/dfu_suffix_generator"
        }
      }
    }
    stage('Tests') {
      parallel {
        stage('Device simulation tests') {
          steps {
            dir("${REPO}/tests/device_simulation") {
              runWaf('.')
              viewEnv() {
                runPytest()
              }
            }
          }
        }
        stage('Build of hardware system tests') {
          steps {
            dir("${REPO}/tests/system_hardware") {
              runWaf('.')
            }
          }
        }
        stage('Host tests') {
          steps {
            dir("${REPO}/tests/host") {
              sh 'make'
              viewEnv() {
                runPytest()
              }
            }
          }
        }
      }
    }
  }
  post {
    success {
      unstash "host-app"
      archiveArtifacts artifacts: "bin/dfu_suffix_generator", fingerprint: true
      updateViewfiles()
    }
    cleanup {
      xcoreCleanSandbox()
    }
  }
}
