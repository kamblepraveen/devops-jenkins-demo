# End-to-End DevOps CI/CD Project

A hands-on DevOps project that takes a Spring Boot application from a
GitHub commit to an automated Kubernetes deployment on AWS.

The lab was built incrementally to practice the complete delivery
lifecycle: source control, CI/CD, build automation, containerization,
registry management, Infrastructure as Code, configuration management,
monitoring, alerting, Kubernetes operations, ingress routing, security
hardening, and troubleshooting.

## Final Architecture

``` text
Developer
   |
   | git push
   v
GitHub
   |
   | Webhook
   v
Jenkins
   |
   +--> Checkout
   +--> Maven Build / Test / Package
   +--> Docker Build
   +--> Docker Hub Push
   |
   | Private VPC SSH
   v
k3s Kubernetes Server
   |
   | kubectl set image
   v
Deployment
   |
   +--> ReplicaSet
   |      +--> Pod
   |      +--> Pod
   |
   v
ClusterIP Service
   |
   v
Traefik Ingress :80
   |
   v
Spring Boot Application
```

Supporting components:

``` text
Terraform       -> AWS infrastructure management
Ansible         -> server/configuration management
CloudWatch      -> infrastructure metrics and alarms
CloudWatch Agent-> memory and disk metrics
SNS             -> email alerting
Grafana Cloud   -> monitoring dashboards
```

## Technology Stack

  Area                       Technology
  -------------------------- ----------------------------------
  Cloud                      AWS
  Operating System           Amazon Linux 2023
  Source Control             Git, GitHub
  CI/CD                      Jenkins
  Build                      Maven
  Application                Java 21, Spring Boot
  Containers                 Docker
  Container Registry         Docker Hub
  Infrastructure as Code     Terraform
  Configuration Management   Ansible
  Container Orchestration    Kubernetes / k3s
  Ingress                    Traefik
  Monitoring                 AWS CloudWatch, CloudWatch Agent
  Alerting                   Amazon SNS
  Visualization              Grafana Cloud

## Repository Structure

``` text
devops-jenkins-demo/
├── README.md
├── Jenkinsfile
├── Dockerfile
├── pom.xml
├── src/
│   ├── main/
│   └── test/
├── ansible/
│   ├── inventory
│   ├── site.yml
│   └── roles/
├── terraform/
│   ├── ec2.tf
│   ├── variables.tf
│   └── data.tf
└── k8s/
    ├── deployment.yaml
    ├── service.yaml
    └── ingress.yaml
```

> The exact directory structure can vary slightly depending on the
> current branch. Secrets, tokens, Terraform state, and SSH private keys
> must never be committed.

## CI/CD Workflow

The final delivery flow is:

1.  Developer modifies the application.
2.  Code is pushed to the `main` branch in GitHub.
3.  GitHub sends a webhook to Jenkins.
4.  Jenkins automatically starts the pipeline.
5.  Jenkins checks out the source code.
6.  Maven compiles, tests, and packages the Spring Boot application.
7.  Jenkins builds a Docker image.
8.  The image is tagged with the Jenkins `BUILD_NUMBER`.
9.  Jenkins authenticates to Docker Hub using Jenkins Credentials.
10. The numbered image is pushed to Docker Hub.
11. Jenkins loads the Kubernetes SSH key using the SSH Agent plugin.
12. Jenkins connects to the k3s server over its private VPC IP.
13. `kubectl set image` updates the Kubernetes Deployment.
14. Kubernetes performs a rolling update.
15. Jenkins waits for `kubectl rollout status` to report success.
16. Traefik routes external HTTP traffic to the ClusterIP Service.
17. The Service routes traffic only to Ready application Pods.

This gives traceability from a Jenkins build to the exact container
image running in Kubernetes.

## Jenkins Pipeline

The final pipeline contains five main stages:

``` text
Checkout
   ↓
Build & Test & Package
   ↓
Docker Build
   ↓
Docker Hub Push
   ↓
Kubernetes Deploy
```

Example build stage:

``` groovy
stage('Build & Test & Package') {
    steps {
        echo 'Building, testing and packaging application...'
        sh 'mvn clean package'
    }
}
```

Example Docker build:

``` groovy
stage('Docker Build') {
    steps {
        sh 'docker build -t devops-demo:jenkins -t kamblepraveen/devops-demo:${BUILD_NUMBER} .'
    }
}
```

Using `${BUILD_NUMBER}` instead of relying only on `latest` provides
deployment traceability.

Example:

``` text
Jenkins Build #21
        ↓
kamblepraveen/devops-demo:21
        ↓
Kubernetes Deployment
```

## Secure Docker Hub Push

Docker Hub credentials are stored in Jenkins Credentials rather than in
the Jenkinsfile.

Credential ID:

``` text
dockerhub-credentials
```

Example:

``` groovy
withCredentials([
    usernamePassword(
        credentialsId: 'dockerhub-credentials',
        usernameVariable: 'DOCKER_USER',
        passwordVariable: 'DOCKER_TOKEN'
    )
]) {
    sh '''
        echo "$DOCKER_TOKEN" | docker login \
          -u "$DOCKER_USER" --password-stdin

        docker push kamblepraveen/devops-demo:${BUILD_NUMBER}

        docker logout
    '''
}
```

The Docker Hub Personal Access Token is never stored in Git.

## Docker

The application is packaged as a Docker image using Java 21.

``` dockerfile
FROM eclipse-temurin:21-jre

WORKDIR /app

COPY target/devops-demo-1.0-SNAPSHOT.jar app.jar

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:8080/ || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
```

Useful commands:

``` bash
docker build -t devops-demo:1.0 .
docker run -d --name devops-demo -p 8080:8080 devops-demo:1.0
docker ps
docker images
docker logs devops-demo
```

## Kubernetes / k3s

k3s is used as a lightweight Kubernetes distribution for this AWS
learning environment.

The application runs with two replicas:

``` yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: devops-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: devops-demo
  template:
    metadata:
      labels:
        app: devops-demo
    spec:
      containers:
        - name: devops-demo
          image: kamblepraveen/devops-demo:<BUILD_NUMBER>
          ports:
            - containerPort: 8080
```

Useful commands:

``` bash
sudo kubectl get nodes
sudo kubectl get deployments
sudo kubectl get rs
sudo kubectl get pods -o wide
sudo kubectl get svc
sudo kubectl get ingress
```

## Kubernetes Self-Healing

Self-healing was tested by manually deleting an application Pod:

``` bash
sudo kubectl delete pod <pod-name>
```

The ReplicaSet automatically created a replacement Pod because the
Deployment desired state required two replicas.

``` text
Desired replicas = 2
Running replicas = 1
        ↓
ReplicaSet detects mismatch
        ↓
New Pod created
        ↓
Running replicas = 2
```

## Kubernetes Scaling

The Deployment was manually scaled from two to four replicas and then
back to two:

``` bash
sudo kubectl scale deployment devops-demo --replicas=4
sudo kubectl get pods

sudo kubectl scale deployment devops-demo --replicas=2
```

This demonstrated Kubernetes horizontal replica management.

## Rolling Updates

Application updates are performed without replacing all Pods
simultaneously.

Manual example:

``` bash
sudo kubectl set image deployment/devops-demo \
devops-demo=kamblepraveen/devops-demo:v2

sudo kubectl rollout status deployment/devops-demo
```

The automated Jenkins pipeline performs the same operation with the
build number:

``` bash
kubectl set image deployment/devops-demo \
devops-demo=kamblepraveen/devops-demo:${BUILD_NUMBER}
```

Kubernetes creates a new ReplicaSet and gradually replaces the old Pods
while maintaining application availability.

## Rollback

Deployment history:

``` bash
sudo kubectl rollout history deployment/devops-demo
```

Rollback:

``` bash
sudo kubectl rollout undo deployment/devops-demo
sudo kubectl rollout status deployment/devops-demo
```

A rollback creates a new revision based on a previous working
configuration.

## Readiness and Liveness Probes

The application uses Kubernetes health probes.

``` yaml
readinessProbe:
  httpGet:
    path: /
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 10

livenessProbe:
  httpGet:
    path: /
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
```

**Readiness probe:** determines whether the Pod should receive Service
traffic.

**Liveness probe:** determines whether Kubernetes should restart the
container.

Both failure scenarios were tested during the lab.

## Kubernetes Service

The final application Service uses `ClusterIP`:

``` yaml
apiVersion: v1
kind: Service
metadata:
  name: devops-demo-service
spec:
  selector:
    app: devops-demo
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
  type: ClusterIP
```

A NodePort was used temporarily during early testing, then removed after
Ingress was configured.

## Traefik Ingress

k3s includes Traefik, which is used as the Ingress Controller.

``` yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: devops-demo-ingress
spec:
  ingressClassName: traefik
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: devops-demo-service
                port:
                  number: 80
```

Final traffic path:

``` text
Browser
   ↓
EC2 Port 80
   ↓
Traefik
   ↓
Ingress Rule
   ↓
ClusterIP Service
   ↓
Ready Kubernetes Pod
   ↓
Spring Boot :8080
```

This replaced direct NodePort exposure.

## Jenkins to Kubernetes Deployment Security

Jenkins communicates with the k3s server using the server's private VPC
address.

``` text
Jenkins EC2
172.31.8.213
      |
      | SSH :22
      | Private VPC
      v
k3s EC2
172.31.11.72
```

The k3s Security Group permits SSH from the Jenkins Security Group.

A dedicated deployment SSH identity was created for Jenkins and stored
in Jenkins Credentials:

``` text
Credential ID: k8s-ssh-key
```

The Jenkins pipeline loads it using:

``` groovy
sshagent(credentials: ['k8s-ssh-key']) {
    sh '''
        ssh ec2-user@172.31.11.72 \
        "sudo kubectl set image deployment/devops-demo \
        devops-demo=kamblepraveen/devops-demo:${BUILD_NUMBER}"

        ssh ec2-user@172.31.11.72 \
        "sudo kubectl rollout status deployment/devops-demo --timeout=120s"
    '''
}
```

No SSH private key is stored in this repository.

## Terraform

Terraform is used for Infrastructure as Code.

An existing EC2 instance was imported into Terraform management:

``` bash
terraform init

terraform import \
  aws_instance.devops_lab \
  i-03e3ed5f4daff87ac

terraform plan
```

Example resource:

``` hcl
resource "aws_instance" "devops_lab" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = data.aws_subnet.devops_subnet.id

  vpc_security_group_ids = [
    data.aws_security_group.devops_sg.id
  ]

  key_name = "devops-lab-key"

  tags = {
    Name = "devops-lab-server"
  }
}
```

After the existing infrastructure and Terraform configuration were
aligned:

``` text
No changes.
Your infrastructure matches the configuration.
```

Terraform state and `.tfvars` files are excluded from Git.

## Ansible

Ansible was used to practice configuration management and originally
automated Docker/Nginx application deployment.

Example structure:

``` text
ansible/
├── inventory
├── site.yml
└── roles/
    ├── app/
    └── nginx/
```

Example inventory:

``` ini
[webserver]
localhost ansible_connection=local
```

Example playbook:

``` yaml
---
- name: Configure DevOps server
  hosts: webserver
  become: true

  roles:
    - app
    - nginx
```

Once Kubernetes became the final application deployment platform, the
Ansible Deploy stage was intentionally removed from the Jenkins
pipeline.

This prevents two different tools from managing the same application
lifecycle.

Ansible remains useful for server bootstrap, package installation,
operating-system configuration, and other configuration-management
tasks.

## Monitoring with CloudWatch

The Jenkins EC2 instance is monitored using AWS CloudWatch.

Standard EC2 metric:

``` text
CPUUtilization
```

CloudWatch Agent publishes:

``` text
mem_used_percent
disk_used_percent
```

Custom namespace:

``` text
DevOpsLab
```

The EC2 instance uses an IAM role with the required CloudWatch Agent
permissions instead of embedding AWS credentials on the server.

## CloudWatch Alarm and SNS

Memory monitoring includes a CloudWatch alarm:

``` text
Alarm: devops-ec2-memory-high
Threshold: > 80%
Period: 1 minute
Evaluation: 1/1 datapoint
```

Notifications are delivered using Amazon SNS.

``` text
CloudWatch Metric
       ↓
CloudWatch Alarm
       ↓
SNS Topic
       ↓
Email Notification
```

The alarm was tested by temporarily lowering the threshold and
confirming email delivery before restoring the normal threshold.

## Grafana Cloud

Grafana Cloud is used to visualize AWS metrics without consuming
additional memory on the Jenkins EC2 server.

Dashboard:

``` text
DevOps Lab Monitoring
```

Panels include:

-   EC2 CPU utilization
-   Memory utilization
-   Root disk utilization

Grafana accesses CloudWatch using an AWS IAM Assume Role configuration
instead of static access keys.

## Security Improvements

Security improvements made during the project include:

-   SSH access restricted through Security Groups.
-   Kubernetes API port `6443` is not publicly exposed.
-   Jenkins communicates with k3s over the private VPC network.
-   Docker Hub PAT stored in Jenkins Credentials.
-   Kubernetes SSH private key stored in Jenkins Credentials.
-   No private keys or tokens stored in Git.
-   AWS IAM roles used where possible.
-   Old Kubernetes NodePort Security Group rule removed.
-   Old Nginx service on the Jenkins server stopped and disabled.
-   Old application container on the Jenkins server stopped.
-   Unnecessary Jenkins-server HTTP port 80 rule removed.
-   Kubernetes Service changed from NodePort to ClusterIP after Ingress
    was implemented.

## Major Problems Solved

This project included real troubleshooting rather than only a happy-path
installation.

  -----------------------------------------------------------------------
  Problem                 Root Cause              Resolution
  ----------------------- ----------------------- -----------------------
  Maven not recognized    Maven/PATH missing      Installed Maven and
                                                  configured environment

  Java target 21 failed   EC2 was using javac 17  Switched build
                                                  environment to Java 21

  Git author identity     Git identity not        Configured `user.name`
  unknown                 configured              and `user.email`

  Git unrelated histories Local and remote repos  Reconciled histories
                          created separately      and pushed merged
                                                  repository

  EC2 SSH permission      Original laptop private Recovered access by
  denied                  key unavailable         replacing
                                                  `authorized_keys`
                                                  through EBS recovery

  GitHub webhook could    Jenkins port blocked /  Corrected SG and
  not connect             public IP changed       webhook URL

  Webhook delivered but   Jenkins GitHub trigger  Enabled GitHub hook
  no build                disabled                trigger

  Ansible Docker module   Collection absent from  Installed required
  missing                 Jenkins environment     collection

  Ansible sudo failed     Jenkins could not       Configured controlled
                          answer sudo prompt      non-interactive sudo
                                                  for lab

  Kubernetes `ClusterIPO` Invalid Service type    Corrected to
                          typo                    `ClusterIP`

  Service DNS failed from Cluster Service DNS is  Tested from appropriate
  EC2 shell               not host DNS            Kubernetes context

  Ping to k3s failed      ICMP not allowed        Tested TCP/22 instead

  Jenkins SSH permission  Public key installed on Added Jenkins public
  denied                  wrong server            key to k3s
                                                  `authorized_keys`

  SSH Agent               Jenkins credential key  Validated original key
  `invalid format`        formatting was          and re-entered complete
                          incorrect               private key

  Readiness Pod became    Intentional invalid     Verified traffic
  `0/1`                   health path             protection and restored
                                                  path

  Liveness restarted      Intentional invalid     Verified self-recovery
  container               health path             and restored path

  NodePort required high  Direct Service exposure Replaced NodePort with
  external port                                   ClusterIP + Traefik
                                                  Ingress

  Duplicate deployment    Ansible and Kubernetes  Removed Ansible deploy
  responsibility          both deployed app       stage; Kubernetes owns
                                                  app lifecycle
  -----------------------------------------------------------------------

## Cost Optimization

The lab was designed to stay inexpensive.

Main strategies:

-   Jenkins uses a small EC2 instance.
-   k3s is used instead of EKS for hands-on Kubernetes practice.
-   Docker Hub is used as the active image registry.
-   Grafana Cloud avoids another always-running monitoring server.
-   No NAT Gateway is required for this lab architecture.
-   No Application Load Balancer is required for the learning
    environment.
-   EC2 instances are stopped when the lab is not being used.
-   EBS volumes remain persistent while instances are stopped.
-   AWS Budget/monitoring alerts are used to watch spending.

> Stopping an EC2 instance stops compute charges, but attached EBS
> storage can still incur charges.

## Useful Troubleshooting Commands

### Jenkins server

``` bash
sudo systemctl status jenkins
sudo ss -lntp | grep 8081
docker ps
docker images
df -h
free -m
```

### Kubernetes server

``` bash
sudo kubectl get nodes
sudo kubectl get deployments
sudo kubectl get rs
sudo kubectl get pods -o wide
sudo kubectl get svc
sudo kubectl get ingress
```

### Rollout

``` bash
sudo kubectl rollout status deployment/devops-demo
sudo kubectl rollout history deployment/devops-demo
```

### Current deployed image

``` bash
sudo kubectl get deployment devops-demo \
-o=jsonpath='{.spec.template.spec.containers[0].image}'; echo
```

### Pod troubleshooting

``` bash
sudo kubectl describe pod <pod-name>
sudo kubectl logs <pod-name>
```

## Key Kubernetes Concepts Practiced

**Deployment** --- manages application Pods, replicas, rolling updates
and rollback.

**ReplicaSet** --- maintains the required number of matching Pods.

**Pod** --- smallest Kubernetes deployable unit containing one or more
containers.

**Service** --- provides a stable endpoint for a group of Pods.

**ClusterIP** --- exposes a Service internally within the Kubernetes
cluster.

**NodePort** --- exposes a Service through a high port on the Kubernetes
node.

**Ingress** --- defines HTTP/HTTPS routing rules to internal Services.

**Ingress Controller** --- implements those rules; Traefik is used in
this project.

**Self-healing** --- Kubernetes recreates failed/deleted Pods to
maintain desired state.

**Rolling Update** --- gradually replaces old Pods with a new
application version.

**Rollback** --- restores a previous Deployment configuration.

## What I Learned

This project provided hands-on experience with:

-   Building an end-to-end CI/CD pipeline
-   Jenkins pipeline design and troubleshooting
-   GitHub webhook integration
-   Maven build lifecycle
-   Docker image creation and registry management
-   Jenkins credential management
-   Infrastructure as Code with Terraform
-   Configuration management with Ansible
-   AWS EC2 and Security Groups
-   CloudWatch Agent and custom metrics
-   SNS alerting
-   Grafana dashboards
-   Kubernetes Deployments, ReplicaSets and Pods
-   Services and networking
-   Self-healing and scaling
-   Rolling updates and rollback
-   Readiness and liveness probes
-   Private-network deployment automation
-   Traefik Ingress
-   Security hardening
-   Cost-conscious cloud architecture
-   Real-world troubleshooting across multiple DevOps layers

## Production Improvements

This is a learning/lab environment. For a production-grade
implementation I would additionally consider:

-   Stable DNS names
-   HTTPS/TLS everywhere
-   Avoiding direct public exposure of the raw Jenkins port
-   Least-privilege IAM, sudo and Kubernetes RBAC
-   Kubernetes Secrets or an external secrets manager
-   Container/dependency vulnerability scanning
-   Pull-request and branch protection policies
-   Separate development, staging and production environments
-   GitOps deployment for larger Kubernetes environments
-   Centralized logging and production SLO/alerting
-   Managed Kubernetes such as Amazon EKS when operational requirements
    justify it

## Project Result

The final automated path is:

``` text
Git Push
   ↓
GitHub
   ↓
Webhook
   ↓
Jenkins
   ↓
Maven
   ↓
Docker Build
   ↓
Docker Hub
   ↓
Private SSH
   ↓
k3s / Kubernetes
   ↓
Rolling Update
   ↓
ClusterIP Service
   ↓
Traefik Ingress
   ↓
Spring Boot Application
```

The project demonstrates not only successful tool installation, but how
the individual DevOps components integrate into one working delivery
platform and how failures across those layers can be diagnosed and
resolved.
