@Library('xmos_jenkins_shared_library@v0.49.0') _

// Get XCommon CMake.
// This is required for compiling a factory image for a DFU test using tools 15.2.1
// to test DFU across XTC tools versions.
def get_xcommon_cmake() {
  dir("${WORKSPACE}") {
    sh "git clone -b v1.3.0 git@github.com:xmos/xcommon_cmake"
  }
}

def build_dfu_test_config() {
    dir("app_usb_aud_xk_316_mc") {
        withEnv(["XMOS_CMAKE_PATH=${WORKSPACE}/xcommon_cmake"]) {
            get_xcommon_cmake()
            sh "cmake -G 'Unix Makefiles' -B build_old_tools"
            sh "xmake -C build_old_tools -j16 1SMi2o2xxxxxx"
            // Create binary file using the old tools xflash that can be written into the device using xflash --write-all during the test
            sh "xflash bin/1SMi2o2xxxxxx/app_usb_aud_xk_316_mc_1SMi2o2xxxxxx.xe -o bin/1SMi2o2xxxxxx/app_usb_aud_xk_316_mc_1SMi2o2xxxxxx.bin"
            // Move to a different directory so it doesn't get overwritten when the same config is compiled with the latest tools
            sh 'mv bin/1SMi2o2xxxxxx bin/1SMi2o2xxxxxx_old_tools'
            sh 'for config in bin/1SMi2o2xxxxxx_old_tools/*.bin; do mv "$config" "${config/%.bin/_old_tools.bin}"; done'
            sh 'for config in bin/1SMi2o2xxxxxx_old_tools/*.xe; do mv "$config" "${config/%.xe/_old_tools.xe}"; done'
            sh 'rm -rf build_old_tools'
        }
    }
}

getApproval()

pipeline {

    agent none

    parameters {
        string(
            name: 'TOOLS_VERSION',
            defaultValue: '15.3.1',
            description: 'XTC tools version'
        )
        string(
            name: 'XMOSDOC_VERSION',
            defaultValue: 'v8.0.1',
            description: 'xmosdoc version'
        )
        string(
            name: 'INFR_APPS_VERSION',
            defaultValue: 'v3.4.0',
            description: 'The infr_apps version'
        )
        choice(
            name: 'TEST_LEVEL', choices: ['smoke', 'default', 'extended'],
            description: 'The level of test coverage to run'
        )
        string(
            name: 'PREV_TOOLS_VERSION',
            defaultValue: '15.2.1',
            description: 'The XTC tools version'
        )
    }

    options {
        skipDefaultCheckout()
        timestamps()
        buildDiscarder(xmosDiscardBuildSettings(onlyArtifacts = false))
    }

    stages {
        stage('Init') {
            agent { label 'x86_64 && linux' }
            steps {
                script {
                    def (server, user, repo) = extractFromScmUrl()
                    env.REPO_NAME = repo
                }
            }
        }
        stage('Parallel Stages') {
            parallel {
                stage('🏗️ Build and docs') {
                    agent {
                        label 'x86_64 && linux && documentation'
                    }

                    stages {
                        stage('Checkout') {
                            steps {

                                println "Stage running on ${env.NODE_NAME}"

                                dir(REPO_NAME){
                                    checkoutScmShallow()
                                }
                            }
                        }

                        stage('Examples build') {
                            steps {
                                dir("${REPO_NAME}/examples") {
                                    dir("i2c/device") {
                                        xcoreBuild()
                                    }
                                    dir("i2c/host_xcore") {
                                        xcoreBuild()
                                    }
                                }
                            }
                        }
                        
                        stage('Repo checks') {
                            steps {
                                warnError("Repo checks failed")
                                {
                                    runRepoChecks("${WORKSPACE}/${REPO_NAME}")
                                }
                            }
                        }

                        stage('Doc build') {
                            steps {
                                dir(REPO_NAME) {
                                    buildDocs()
                                }
                            }
                        }

                        stage("Archive sandbox") {
                            steps {
                                archiveSandbox(REPO_NAME)
                            }
                        }
                    }
                    post {
                        cleanup {
                            xcoreCleanSandbox()
                        }
                    }
                } // stage 'Build and docs'

                stage('🔧 36x0 - I2C HW Tests') {
                    agent {
                        label 'xvf3610_int'
                    }

                    // Note this executor connects to a RPi which runs 32b Buster. So we
                    // cannot use the pre-built 64b host apps. The test itself builds the host app from source.
                    stages {
                        stage('Checkout') {
                            steps {
                                println "Stage running on ${env.NODE_NAME}"

                                dir(REPO_NAME){
                                    checkoutScmShallow()
                                    // Get dependencies (lib_device_control) for the I2C host tests on RPi and build example for test
                                    dir("examples/i2c/device") {
                                        withTools(params.TOOLS_VERSION) {
                                            xcoreBuild(archiveBins: false)
                                        }
                                    }
                                }
                            }
                        }
                        stage('36x0 I2C DFU tests') {
                            steps {
                                dir ("${REPO_NAME}/tests") {
                                    withTools(params.TOOLS_VERSION) {
                                        createVenv(reqFile: "requirements.txt")
                                        withVenv {
                                            dir("i2c_rpi_hardware") {
                                                withXTAG(["XVF3610_INT"]) {  xtagIds ->
                                                    sh "echo ${xtagIds}"
                                                    runPytest("-n=1 --adapter-id ${xtagIds[0]}")
                                                }
                                            }
                                        }
                                        
                                        // Build the legacy project is the test for xcommon support
                                        dir("legacy_build_test") {
                                            withTools(params.TOOLS_VERSION) {
                                                sh "xmake -j"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    post {
                        cleanup {
                            xcoreCleanSandbox()
                        }
                    }
                } // stage "🔧 I2C HW Tests"

                stage('🔧 Flash Testing') {
                    agent {
                        label 'sw-hw-xcai-exp0 || sw-hw-xcai-exp1 || sw-hw-xcai-exp2 || sw-hw-xcai-exp3'
                    }
                    stages {
                        stage('Checkout') {
                            steps {
                                println "Stage running on ${env.NODE_NAME}"
                                dir(REPO_NAME){
                                    checkoutScmShallow()
                                }
                            }
                        }
                        stage('Flash Hardware Test') {
                            steps {
                                dir ("${REPO_NAME}/tests") {
                                    withTools(params.TOOLS_VERSION) {
                                        createVenv(reqFile: "requirements.txt")
                                        withVenv {
                                            dir("dummy") {
                                                xcoreBuild(archiveBins: false)
                                            }
                                            dir("flash_hardware/prepare_upgrade_slot") {
                                                withXTAG(["XCORE-AI-EXPLORER"]) {
                                                    xtagIds -> runPytest("-n=1 --adapter-id ${xtagIds[0]}")
                                                }
                                            }
                                            dir("system_hardware/write_upgrade_boot_only") {
                                                withXTAG(["XCORE-AI-EXPLORER"]) {
                                                    xtagIds -> runPytest("-n=1 --adapter-id ${xtagIds[0]}")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    post {
                        cleanup {
                            xcoreCleanSandbox()
                        }
                    }
                } // stage "🔧 Testing"

            } // parallel
        } // stage Parallel Stages

        stage('Build Tests') {
            agent {
                label 'x86_64 && linux'
            }
            steps {
                println "Stage running on ${env.NODE_NAME}"
                dir(REPO_NAME){
                    checkoutScmShallow()
                }
                dir("${REPO_NAME}/tests") {
                    dir ("usb_dfu") {
                        withTools(params.PREV_TOOLS_VERSION) {
                            // Build one of the configs with old XTC tools (15.2.1) for a DFU test which tests if an older tools version factory executable
                            // can download an upgrade image built with the latest tools.
                            build_dfu_test_config()
                        }
                        xcoreBuild(archiveBins: false, cmakeOpts: "-DENABLE_I2S_TIMING_CHECK=ON")
                        stash includes: '**/bin/**/*.xe, **/bin/**/*.bin', name: 'usb_dfu_xk_bin', useDefaultExcludes: false
                    }
                    dir ("clear_upgrade") {
                        xcoreBuild(archiveBins: false)
                    }
                    stash includes: 'clear_upgrade/bin/clear_upgrade.xe', name: 'dfu_clear_upgrade_bin', useDefaultExcludes: false
                }
            }
            post {
                cleanup {
                    xcoreCleanSandbox()
                }
            }
        }
        
        stage('Host Test Parallel Stages') {
            parallel {
                
                stage('🔧 Linux Host') {
                    agent {
                        label 'x86_64 && linux'
                    }
                    stages {
                        stage('Checkout') {
                            steps {
                                dir(REPO_NAME) {
                                    checkoutScmShallow()
                                }
                            }
                        }

                        stage('Build Linux host apps') {
                            steps {
                                dir(REPO_NAME) {
                                    dir("host") {
                                        sh "cmake -B build"
                                        sh "cmake --build build"
                                        sh "mkdir -p linux-x86_64"
                                        sh "cp suffix_generator/bin/dfu_suffix_generator linux-x86_64"
                                        sh "cp xmosdfu/bin/xmosdfu linux-x86_64"
                                    }
                                    archiveArtifacts artifacts: "host/linux-x86_64/*", fingerprint: true
                                }
                            }
                        }
                        stage('Run sim tests') {
                            steps {
                                dir("${REPO_NAME}/tests") {
                                    withTools(params.TOOLS_VERSION) {
                                        createVenv(reqFile: "requirements.txt")
                                        withVenv {
                                            dir("dummy") {
                                                xcoreBuild(archiveBins: false)
                                            }
                                            dir("host") {
                                                sh "cmake -B build"
                                                sh "cmake --build build"
                                                runPytest("--level=${params.TEST_LEVEL}")
                                            }
                                            dir("device_simulation/dfu") {
                                                runPytest("--level=${params.TEST_LEVEL}")
                                            }
                                            dir("device_simulation/modules") {
                                                runPytest("--level=${params.TEST_LEVEL}")
                                            }
                                            dir("device_simulation/dfu_flash") {
                                                runPytest("--level=${params.TEST_LEVEL}")
                                            }
                                            dir("device_simulation/dfu_dnload") {
                                                runPytest("--level=${params.TEST_LEVEL}")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    post {
                        cleanup {
                            xcoreCleanSandbox()
                        }
                    }
                }  // Linux Host

                stage('🔧 Mac Intel host') {
                    agent {
                        label 'usb_audio && macos && x86_64'
                    }
                    stages {
                        stage('Build Mac Intel host app') {
                            steps {
                                println "Stage running on ${env.NODE_NAME}"

                                dir(REPO_NAME) {
                                    checkoutScmShallow()
                                    dir("host") {
                                        sh "cmake -B build"
                                        sh "cmake --build build"
                                        sh "mkdir -p macos-x86_64"
                                        sh "cp suffix_generator/bin/dfu_suffix_generator macos-x86_64"
                                        sh "cp xmosdfu/bin/xmosdfu macos-x86_64"
                                        dir("xmosdfu/bin") {
                                            stash includes: 'xmosdfu', name: 'mac_intel_xmosdfu_exe'
                                        }
                                    }
                                    archiveArtifacts artifacts: "host/macos-x86_64/*", fingerprint: true

                                }
                            }
                        }

                        stage('Mac Intel HW DFU tests') {
                            steps {
                                dir("${REPO_NAME}/tests") {
                                    unstash 'dfu_clear_upgrade_bin'
                                    
                                    withTools(params.TOOLS_VERSION) {
                                        createVenv(reqFile: "requirements.txt")
                                        // TODO - confirm this is still needed, inherited from sw_usb_audio
                                        withEnv(["USBA_MAC_PRIV_WORKAROUND=1"]) {
                                            withVenv() {
                                                dir("${env.VIRTUAL_ENV}/src/hardware-test-tools/xmosdfu") {
                                                    // Mac testing requires the xmosdfu exe to be here.
                                                    unstash 'mac_intel_xmosdfu_exe'
                                                }
                                                dir ("usb_dfu") {
                                                    unstash 'usb_dfu_xk_bin'

                                                    withXTAG(["usb_audio_mc_xs2_dut", "usb_audio_xcai_exp_dut"]) { xtagIds ->
                                                        sh "pytest -v --level nightly --junitxml=pytest_result_mac_intel.xml \
                                                            -o xk_216_mc_dut=${xtagIds[0]} -o xk_evk_xu316_dut=${xtagIds[1]} -k dfu"
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    post {
                        always {
                            junit "${REPO_NAME}/tests/usb_dfu/pytest_result_mac_intel.xml"
                        }
                        cleanup {
                            xcoreCleanSandbox()
                        }
                    }
                }  // Mac x86 host

                stage('🔧 Mac arm Host') {
                    agent {
                        label 'usb_audio && arm64 && macos'
                    }
                    stages {
                        stage('Build Mac arm host app') {
                            steps {
                                println "Stage running on ${env.NODE_NAME}"

                                dir(REPO_NAME) {
                                    checkoutScmShallow()
                                    dir("host") {
                                        sh "cmake -B build"
                                        sh "cmake --build build"
                                        sh "mkdir -p macos-arm64"
                                        sh "cp suffix_generator/bin/dfu_suffix_generator macos-arm64"
                                        sh "cp xmosdfu/bin/xmosdfu macos-arm64"
                                        dir("xmosdfu/bin") {
                                            stash includes: 'xmosdfu', name: 'mac_arm_xmosdfu_exe'
                                        }

                                    }
                                    archiveArtifacts artifacts: "host/macos-arm64/*", fingerprint: true
                                }
                            }
                        }
                        stage('Mac Arm HW DFU tests') {
                            steps {
                                dir("${REPO_NAME}/tests") {
                                    unstash 'dfu_clear_upgrade_bin'
                                    
                                    withTools(params.TOOLS_VERSION) {
                                        createVenv(reqFile: "requirements.txt")
                                        // TODO - confirm this is still needed, inherited from sw_usb_audio
                                        withEnv(["USBA_MAC_PRIV_WORKAROUND=1"]) {
                                            withVenv() {
                                                dir("${env.VIRTUAL_ENV}/src/hardware-test-tools/xmosdfu") {
                                                    // Mac testing requires the xmosdfu exe to be here.
                                                    unstash 'mac_arm_xmosdfu_exe'
                                                }
                                                dir ("usb_dfu") {
                                                    unstash 'usb_dfu_xk_bin'

                                                    withXTAG(["usb_audio_mc_xcai_dut"]) { xtagIds ->
                                                        sh "pytest -v --level nightly --junitxml=pytest_result_mac_arm.xml -o xk_316_mc_dut=${xtagIds[0]} -k dfu"
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    post {
                        always {
                            junit "${REPO_NAME}/tests/usb_dfu/pytest_result_mac_arm.xml"
                        }
                        cleanup {
                            xcoreCleanSandbox()
                        }
                    }
                }  // Build Mac arm host

                stage('🔧 Windows host') {
                    agent {
                        label 'x86_64 && windows11 && usb_audio'
                    }
                    stages {
                        stage('Build Windows host app') {
                            steps {
                                println "Stage running on ${env.NODE_NAME}"

                                dir(REPO_NAME) {
                                    checkoutScmShallow()
                                    withVS() {
                                        dir("host") {
                                            bat "cmake -B build -G Ninja"
                                            bat "cmake --build build"
                                            sh "mkdir -p windows-x64"
                                            bat "copy /Y suffix_generator\\bin\\dfu_suffix_generator.exe windows-x64"
                                            bat "copy /Y xmosdfu\\bin\\xmosdfu.exe windows-x64"
                                        }
                                        archiveArtifacts artifacts: "host/windows-x64/*", fingerprint: true
                                    } // withVS()
                                }
                            }
                        }
                        stage('Windows HW DFU tests') {
                            steps {
                                dir("${REPO_NAME}/tests") {
                                    unstash 'dfu_clear_upgrade_bin'
                                    
                                    withTools(params.TOOLS_VERSION) {
                                        createVenv(reqFile: "requirements.txt")
                                        withVenv() {
                                            dir ("usb_dfu") {
                                                unstash 'usb_dfu_xk_bin'

                                                withXTAG(["usb_audio_mc_xcai_dut"]) { xtagIds ->
                                                    sh "pytest -v --level nightly --junitxml=pytest_result_win_11.xml -o xk_316_mc_dut=${xtagIds[0]} -k dfu"
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    post {
                        always {
                            junit "${REPO_NAME}/tests/usb_dfu/pytest_result_win_11.xml"
                        }
                        cleanup {
                            xcoreCleanSandbox()
                        }
                    }
                }  // Windows host

                stage('🔧 64bit Raspberry Pi host') {
                    agent {
                        label 'pi'
                    }
                    stages {
                        stage('Build Raspberry Pi host app') {
                            steps {
                                println "Stage running on ${env.NODE_NAME}"

                                dir(REPO_NAME) {
                                    checkoutScmShallow()
                                    dir("host") {
                                        sh "cmake -B build"
                                        sh "cmake --build build"
                                        sh "mkdir -p RPi-64"
                                        sh "cp suffix_generator/bin/dfu_suffix_generator RPi-64"
                                        sh "cp dfu_i2c/lib/libdfuctrl_i2c_1.0.a RPi-64"
                                        sh "cp dfu_i2c/bin/dfu_i2c RPi-64"
                                        sh "cp xmosdfu/bin/xmosdfu RPi-64"

                                    }
                                    archiveArtifacts artifacts: "host/RPi-64/*", fingerprint: true
                                }
                            }
                        }
                    }
                    post {
                        cleanup {
                            xcoreCleanSandbox()
                        }
                    }
                }  // Raspberry Pi host
            }
        } // stage Host Test Parallel Stages

        stage(' Release') {
            when {
                expression { triggerRelease.isReleasable() }
            }
            steps {
                triggerRelease()
            }
        } // stage "Release"
    }
}
