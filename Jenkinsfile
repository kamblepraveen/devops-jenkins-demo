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
