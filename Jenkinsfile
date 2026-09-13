pipeline {
    agent any

    stages {

        stage('Checkout') {
            steps {
                echo 'Checking out source code...'
            }
        }

        stage('Build') {
            steps {
                echo 'Building application...'
                dir('devops-jenkins-demo') {
                    bat 'mvn clean compile'
                }
            }
        }

        stage('Test') {
            steps {
                echo 'Running tests...'
                dir('devops-jenkins-demo') {
                    bat 'mvn test'
                }
            }
        }

        stage('Package') {
            steps {
                echo 'Packaging application...'
                dir('devops-jenkins-demo') {
                    bat 'mvn package'
                }
            }
        }
    }
}
