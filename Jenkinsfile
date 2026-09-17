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

            echo "Waiting for application health..."

            for i in {1..12}; do
                STATUS=$(docker inspect -f '{{.State.Health.Status}}' devops-demo 2>/dev/null || echo "starting")
                echo "Health status: $STATUS"

                if [ "$STATUS" = "healthy" ]; then
                    echo "Application is healthy!"
                    exit 0
                fi

                if [ "$STATUS" = "unhealthy" ]; then
                    echo "Application is unhealthy!"
                    docker logs devops-demo
                    exit 1
                fi

                sleep 5
            done

            echo "Health check timed out!"
            docker logs devops-demo
            exit 1
        '''
    }
}
    }
}
