pipeline {
    agent any

    stages {

        stage('Checkout') {
            steps {
                echo 'Checking out source code...'
                checkout scm
            }
        }

        stage('Build & Test & Package') {
            steps {
                echo 'Building, testing and packaging application...'
                sh 'mvn clean package'
            }
        }

        stage('Docker Build') {
            steps {
                echo 'Building Docker image...'
                sh 'docker build -t devops-demo:jenkins .'
            }
        }

        stage('Docker Hub Push') {
    steps {
        echo "Pushing Docker image for Jenkins build ${BUILD_NUMBER}..."

        withCredentials([
            usernamePassword(
                credentialsId: 'dockerhub-credentials',
                usernameVariable: 'DOCKER_USER',
                passwordVariable: 'DOCKER_TOKEN'
            )
        ]) {
            sh '''
                echo "$DOCKER_TOKEN" | docker login -u "$DOCKER_USER" --password-stdin

                docker tag devops-demo:jenkins \
                kamblepraveen/devops-demo:${BUILD_NUMBER}

                docker push \
                kamblepraveen/devops-demo:${BUILD_NUMBER}
            '''
        }
    }
}

        stage('Ansible Deploy') {
            steps {
                echo 'Deploying application using Ansible...'

                sh '''
                    /usr/bin/ansible-playbook \
                    -i ansible/inventory \
                    ansible/site.yml
                '''
            }
        }
    }
}
