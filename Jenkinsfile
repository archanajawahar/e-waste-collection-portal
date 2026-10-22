
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    parameters {
        choice(
            name: 'RELEASE_MODE',
            choices: ['STABLE', 'FAULTY_ROLLBACK_TEST'],
            description: 'Choose stable deployment or test automatic rollback.'
        )
        booleanParam(
            name: 'DEPLOY_TO_KUBERNETES',
            defaultValue: true,
            description: 'Deploy to Kubernetes after successful image push.'
        )
    }

    environment {
        DOCKERHUB_USERNAME = 'archanajawahar14'
        IMAGE_NAME = 'e-waste-portal'
        DOCKER_CREDENTIALS_ID = 'dockerhub-creds'
        KUBECONFIG_CREDENTIALS_ID = 'kubernetes-creds'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                bat 'git log -1 --oneline'
            }
        }

        stage('Parallel Validation') {
            parallel {
                stage('HTML Content Test') {
                    steps {
                        bat 'findstr /C:"Central Civic Collection Centre" index.html'
                        bat 'findstr /C:"Successfully recycled" index.html'
                        bat 'findstr /C:"scheduleForm" index.html'
                    }
                }

                stage('Deployment Manifest Test') {
                    steps {
                        bat 'findstr /C:"kind: Deployment" deployment.yaml'
                        bat 'findstr /C:"readinessProbe" deployment.yaml'
                        bat 'findstr /C:"kind: Service" deployment.yaml'
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    env.IMAGE_TAG = "v${env.BUILD_NUMBER}"

                    bat "docker build -t ${env.DOCKERHUB_USERNAME}/${env.IMAGE_NAME}:${env.IMAGE_TAG} ."

                    bat "docker image inspect ${env.DOCKERHUB_USERNAME}/${env.IMAGE_NAME}:${env.IMAGE_TAG} > image-inspect.json"
                }
            }
        }

        stage('Local Container Smoke Test') {
            steps {
                script {
                    bat 'docker rm -f e-waste-smoke >NUL 2>&1 || exit /b 0'

                    bat "docker run -d --name e-waste-smoke -p 18087:80 ${env.DOCKERHUB_USERNAME}/${env.IMAGE_NAME}:${env.IMAGE_TAG}"

                    bat '''
                    powershell -NoProfile -ExecutionPolicy Bypass -Command "$ok=$false; for($i=0;$i -lt 15;$i++){try{$r=Invoke-WebRequest -UseBasicParsing http://localhost:18087; if($r.StatusCode -eq 200 -and $r.Content.Contains('Central Civic Collection Centre')){$ok=$true;break}}catch{}; Start-Sleep -Seconds 2}; if(-not $ok){docker logs e-waste-smoke; exit 1}"
                    '''

                    bat 'docker rm -f e-waste-smoke'
                }
            }
        }

        stage('Archive Build Artifacts') {
            steps {
                archiveArtifacts(
                    artifacts: 'index.html,Dockerfile,Jenkinsfile,deployment.yaml,image-inspect.json',
                    fingerprint: true
                )
            }
        }

        stage('Push Image to Docker Hub') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DH_USER',
                        passwordVariable: 'DH_TOKEN'
                    )
                ]) {
                    script {
                        int loginStatus = bat(
                            returnStatus: true,
                            script: '''
                            @echo off
                            powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $env:DH_TOKEN | docker login --username $env:DH_USER --password-stdin; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }"
                            '''
                        )

                        if (loginStatus != 0) {
                            error('Docker Hub login failed. Check the credential type, username, token permissions, and token value.')
                        }

                        try {
                            bat "docker push ${env.DOCKERHUB_USERNAME}/${env.IMAGE_NAME}:${env.IMAGE_TAG}"
                        } finally {
                            bat 'docker logout'
                        }
                    }
                }
            }
        }

        stage('Deploy and Verify on Kubernetes') {
            when {
                expression {
                    return params.DEPLOY_TO_KUBERNETES
                }
            }

            steps {
                script {
                    withCredentials([
                        file(
                            credentialsId: 'kubernetes-creds',
                            variable: 'KUBECONFIG'
                        )
                    ]) {
                        bat 'kubectl version --client'
                        bat 'kubectl apply -f deployment.yaml'

                        bat "kubectl set image deployment/e-waste-portal e-waste-portal=${env.DOCKERHUB_USERNAME}/${env.IMAGE_NAME}:${env.IMAGE_TAG}"

                        if (params.RELEASE_MODE == 'FAULTY_ROLLBACK_TEST') {
                            echo 'Testing rollback using an invalid readiness probe.'

                            bat '''
                            kubectl patch deployment e-waste-portal --type=strategic -p "{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"e-waste-portal\",\"readinessProbe\":{\"httpGet\":{\"path\":\"/faulty-health-check\",\"port\":\"http\"},\"initialDelaySeconds\":1,\"periodSeconds\":3,\"timeoutSeconds\":1,\"failureThreshold\":2}}]}}}}"
                            '''
                        }

                        int rolloutStatus = bat(
                            returnStatus: true,
                            script: 'kubectl rollout status deployment/e-waste-portal --timeout=90s'
                        )

                        if (rolloutStatus != 0) {
                            echo 'Deployment failed. Collecting diagnostics and attempting rollback.'

                            bat 'kubectl get pods -l app=e-waste-portal -o wide'
                            bat 'kubectl describe deployment e-waste-portal'
                            bat 'kubectl rollout history deployment/e-waste-portal'

                            int undoStatus = bat(
                                returnStatus: true,
                                script: 'kubectl rollout undo deployment/e-waste-portal'
                            )

                            if (undoStatus != 0) {
                                error('Rollback command failed. Check Kubernetes access and deployment history.')
                            }

                            int recoveryStatus = bat(
                                returnStatus: true,
                                script: 'kubectl rollout status deployment/e-waste-portal --timeout=90s'
                            )

                            if (recoveryStatus != 0) {
                                error('Rollback was requested, but the previous revision did not become healthy.')
                            }

                            bat 'kubectl get deployment e-waste-portal'
                            bat 'kubectl get pods -l app=e-waste-portal'

                            error('The rollout failed. Rollback was completed and recovery was checked.')
                        }

                        bat 'kubectl get deployment e-waste-portal'
                        bat 'kubectl get pods -l app=e-waste-portal'
                        bat 'kubectl get service e-waste-portal'
                    }
                }
            }
        }
    }

    post {
        always {
            bat 'docker rm -f e-waste-smoke >NUL 2>&1 || exit /b 0'
            echo 'Pipeline finished. Review the stage logs and deployment status.'
        }
    }
}
