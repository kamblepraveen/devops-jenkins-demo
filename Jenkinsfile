pipeline {
    agent any

    stages {

        stage('Checkout') {
            steps {
                echo 'Checking out source code...'
                checkout scm
            }
        }

        stage('Build') {
            steps {
                echo 'Building application...'
                sh 'mvn clean compile'
            }
        }

        stage('Test') {
            steps {
                echo 'Running tests...'
                sh 'mvn test'
            }
        }

        stage('Package') {
            steps {
                echo 'Packaging application...'
                sh 'mvn package'
            }
        }

        stage('Docker Build') {
            steps {
                echo 'Building Docker image...'
                sh 'docker build -t devops-demo:jenkins .'
            }
        }

        stage('Deploy') {
        steps {
        echo 'Deploying application...'
        sh '''
            docker stop devops-demo || true
            docker rm devops-demo || true
            docker run -d --name devops-demo -p 8080:8080 devops-demo:jenkins
        '''
    }
}
    }
}
