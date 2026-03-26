# EKS Infrastructure & CI/CD Deployment

## 📋 Architecture Overview
We are setting up a decoupled CI/CD workflow:
1.  **Infrastructure Pipeline:** Uses Terraform to build VPC, EKS, RDS, and S3.
2.  **Backend Pipeline:** Builds Java/Maven app, pushes Docker image to **Docker Hub**, and deploys to **EKS**.
3.  **Frontend Pipeline:** Builds React/Vue app and deploys static files to **S3**.

---

## Phase 1: IAM & Security Setup (Best Practices)

Before launching the server, we follow "Sir's" advice: **Do not use hardcoded AWS keys.** Use an **IAM Role (Instance Profile)**.

### Step 1: Create IAM Role for EC2
1.  Go to **AWS Console** -> **IAM** -> **Roles** -> **Create Role**.
2.  **Trusted Entity:** Select **AWS Service** -> **EC2**.
3.  **Permissions:** Attach `AdministratorAccess` (for learning/lab purposes) or specific policies like `AmazonEKSFullAccess`, `AmazonS3FullAccess`.
4.  **Role Name:** `Jenkins-Server-Role`.
5.  Click **Create Role**.

### Step 2: Attach Role to EC2
1.  Go to **EC2 Console**.
2.  Select your Jenkins Instance (or launch a new one).
3.  **Actions** -> **Security** -> **Modify IAM Role**.
4.  Select `Jenkins-Server-Role` -> **Update IAM Role**.

> **Result:** Your Jenkins server can now talk to AWS (S3, EKS, EC2) automatically without you typing `aws configure` or storing keys.

---

## Phase 2: Launch Jenkins Server with User Data

We need a server with 
[Jenkins](https://www.jenkins.io/doc/book/installing/linux/#debianubuntu),
[Docker](https://docs.docker.com/engine/install/ubuntu/),
Maven,
[Terraform](https://developer.hashicorp.com/terraform/install#linux),
[aws cli](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html).
Kubectl,
### User Data Script
Copy and paste this into **Advanced Details** -> **User Data** when launching an **Ubuntu 22.04** EC2 instance.

```bash
#!/bin/bash
# Update System
sudo apt update -y

# 1. Install Java
sudo apt install fontconfig openjdk-17-jre -y

# 2. Install Jenkins
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update
sudo apt install jenkins -y

# 3. Install Docker
sudo apt install docker.io -y
sudo systemctl start docker
sudo systemctl enable docker

# 4. Install Maven (Required for Backend Pipeline)
sudo apt install maven -y

# 5. Install Kubectl (Required for Backend Deployment)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# 6. Install Terraform
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform -y

# 7. Install AWS CLI
sudo apt install zip -y
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update

# Start Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins
```

### Post-Launch Configuration
1.  Access Jenkins at `http://<PUBLIC-IP>:8080`.
2.  Get Password: `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`.
3.  Install **Suggested Plugins**.

Next you go to **Manage Jenkins -> Plugins**, search for and install these specific ones to cover your entire architecture:

1.  **Git Plugin** (Mandatory)
2.  **Pipeline** (Mandatory)
3.  **Maven Integration** (Mandatory)
4.  **Docker Pipeline** (Mandatory)
5.  **Workspace Cleanup Plugin** (Mandatory - for `cleanWs()`)
6.  **Credentials Binding Plugin** (**CRITICAL** - for secrets)
7.  **GitHub Plugin** (Recommended - for Webhooks)

---

## Phase 3: Fix Permissions (The "Sir's" Fix)

Jenkins runs as a `jenkins` user, but it needs access to Docker.

### 1. Add Jenkins to Docker Group
Run this on the EC2 server terminal:
```bash
sudo usermod -aG docker jenkins
```

### 2. Restart Jenkins
**Crucial Step:** The permission change doesn't apply until restart.
```bash
sudo systemctl restart jenkins
```

### 3. Verify IAM Role
Verify the server is using the Instance Profile, not keys.
```bash
aws sts get-caller-identity
```
*Expected Output:* An ARN containing `assumed-role/Jenkins-Server-Role/...`. If you see a User ARN, your Instance Profile isn't attached correctly.

---

###  Create the S3 Bucket Manually

You need to create this specific bucket manually in AWS Console first.

#### Step 1: Go to AWS Console
1.  Log in to AWS.
2.  Search for **S3** in the top search bar.
3.  Click **Create bucket**.

#### Step 2: Configure the Bucket
1.  **Bucket name:** You must type the **exact** name from the error:
    `my-terraform-state-bucket-jk-tf-user-vicky`
2.  **Region:** Select `us-east-1` (or whatever region you are using for your Jenkins server).
3.  **Block Public Access settings:** Keep **"Block all public access"** enabled (Security best practice for state files).

#### Step 3: (Important) Enable Versioning
1.  Scroll down to **Bucket Versioning**.
2.  Click **Enable**.
    *   *Why?* This allows you to recover previous versions of your state file if someone accidentally deletes a resource.

#### Step 4: Create
Click **Create bucket** at the bottom.


---
## Phase 4: Pipeline 1 - Infrastructure (Terraform)

This pipeline builds the foundation (VPC, EKS Cluster, RDS, S3).

### Prerequisites
Ensure your Terraform repo (`cdec-b48-terraform`) has the file `infra/radison-hms-infra/vars/staging.tfvars`.

### Create "Infra-Pipeline" Job in Jenkins
Select **Pipeline** and use the following script.

**Jenkinsfile (Infrastructure):**
```groovy
pipeline {
    agent any
    stages{
        stage('PULL'){
            steps{
                // Pulling the Infrastructure Code
                git branch: 'main', url: 'https://github.com/shubhamkalsait/cdec-b48-terraform.git'
            }
        }
        stage('PLAN'){
            steps{
                sh'''
                cd infra/radison-hms-infra
                terraform init
                terraform plan --var-file=vars/staging.tfvars
                '''
            }
        }
        stage('APPROVAL'){
            steps{
                // Manual approval step to prevent accidental destruction
                input 'Wait for approval to Apply Infrastructure'
            }
        }
        stage('APPLY'){
            steps{
                sh'''
                cd infra/radison-hms-infra
                terraform init
                terraform apply -auto-approve --var-file=vars/staging.tfvars
                '''
            }
        }
    }
}
```
*   **Note:** Run this pipeline **FIRST**. It will take ~15 minutes. It creates the S3 bucket (`cbz-easycrud-b48`) and the EKS Cluster.

---

## Phase 5: Pipeline 2 - Backend Deployment

This pipeline builds the Java app, creates a Docker image, pushes to **Docker Hub**, and deploys to **EKS**.

### Prerequisites
1.  **Docker Hub Login:** Since the pipeline pushes to `shubhamkalsait1/backend-app`, you must log in to Docker Hub on the server once.
    ```bash
    su - jenkins
    docker login
    # Enter your Docker Hub username and password
    ```
2.  **Kubeconfig:** Ensure the server can talk to the EKS cluster created in Phase 4.
    ```bash
    aws eks update-kubeconfig --name radison-hms-cluster --region us-east-1
    # (Replace name/region with your specific values)
    ```

### Repository Structure
Ensure `EasyCRUD` repo has:
*   `backend/pom.xml` (Maven file)
*   `backend/Dockerfile`
*   `backend/yaml/deployment.yaml` & `service.yaml` (K8s manifests)

### Create "Backend-Pipeline" Job in Jenkins

**Jenkinsfile (Backend):**
```groovy
pipeline {
    agent any
    stages {
        stage('PULL'){
            steps{
                // Using branch 'cdec-b48' as per your snippet
                git branch: 'cdec-b48', url: 'https://github.com/shubhamkalsait/EasyCRUD.git'
            }
        }
        stage ('BUILD'){
            steps{
                sh '''
                    cd backend
                    mvn clean package -DskipTests
                '''
            }
        }
        stage ('DOCKER-BUILD'){
            steps{
                sh '''cd backend
                    # Building and Pushing to Docker Hub
                    docker build . -t shubhamkalsait1/backend-app:latest
                    docker push shubhamkalsait1/backend-app:latest
                    # Cleaning up local image to save space
                    docker rmi shubhamkalsait1/backend-app:latest
                    '''
            }
        }
        stage ('DEPLOY'){
            steps{
                sh '''cd backend
                    # Applying manifests located in backend/yaml/ folder
                    kubectl apply -f yaml/
                    '''
            }
        }
    }
    post {
        always {
            // Clean workspace to avoid conflicts in next build
            cleanWs(cleanWhenNotBuilt: false,
                    deleteDirs: true,
                    disableDeferredWipeout: true,
                    notFailBuild: true,
                    patterns: [[pattern: '.gitignore', type: 'INCLUDE'],
                               [pattern: '.propsfile', type: 'EXCLUDE']])
        }
    }
}
```

---

## Phase 6: Pipeline 3 - Frontend Deployment

This pipeline builds the React/Vue app and pushes the static assets to **S3**.

### Prerequisites
*   The S3 bucket `cbz-easycrud-b48` must exist (created by Terraform in Phase 4).

### Create "Frontend-Pipeline" Job in Jenkins

**Jenkinsfile (Frontend):**
```groovy
pipeline {
    agent any
    stages {
        stage ('PULL'){
            steps{
                // Using branch 'main'
                git branch: 'main', url: 'https://github.com/shubhamkalsait/EasyCRUD.git'
            }
        }
        stage ('BUILD'){
            steps{
                sh '''
                    cd frontend
                    npm install
                    npm run build
                '''
            }
        }
        stage ('DEPLOY'){
            steps{
                sh '''
                    cd frontend
                    # Sync the 'dist' folder (standard React build output) to S3
                    aws s3 cp dist/ s3://cbz-easycrud-b48/ --recursive
                '''
            }
        }
    }
    post {
        always {
            cleanWs(cleanWhenNotBuilt: false,
                    deleteDirs: true,
                    disableDeferredWipeout: true,
                    notFailBuild: true,
                    patterns: [[pattern: '.gitignore', type: 'INCLUDE'],
                               [pattern: '.propsfile', type: 'EXCLUDE']])
        }
    }
}
```

---

## Phase 7: Execution Order & Verification

1.  **Run Infra Pipeline:**
    *   Wait for "Approval".
    *   Approve.
    *   Wait for `APPLY` to finish.
    *   *Verify:* Go to AWS Console -> EKS. You should see the cluster. Go to S3. You should see `cbz-easycrud-b48`.

2.  **Run Backend Pipeline:**
    *   *Verify:* `kubectl get pods -n default` (or your namespace). You should see backend pods running.
    *   *Verify:* Check Docker Hub -> `shubhamkalsait1/backend-app` tags.

3.  **Run Frontend Pipeline:**
    *   *Verify:* Go to S3 Console -> Bucket `cbz-easycrud-b48`. You should see `index.html` and static assets.

---

## 📚 Summary of Key Concepts (Interview Prep)

1.  **Why IAM Instance Profile?**
    *   **Answer:** It allows EC2 instances to securely make API requests to AWS services without embedding long-term credentials (Access Keys) in the code or server. It follows the principle of least privilege and is easier to manage (rotate permissions at the role level, not individual servers).

2.  **Why `usermod -aG docker jenkins`?**
    *   **Answer:** Jenkins runs as a service user (`jenkins`). By default, this user cannot execute the `docker` command. Adding it to the `docker` group grants it permission to access the Docker socket without requiring `sudo`, which is necessary for CI/CD pipelines to build images.

3.  **Decoupled Pipelines:**
    *   **Concept:** We separate Infrastructure (Terraform) from Application (Jenkins Docker/K8s/S3).
    *   **Benefit:** Infrastructure changes rarely happen (weekly/monthly). Code changes happen frequently (hourly/daily). Running a 15-minute Terraform apply for every code commit is inefficient.

4.  **Backend vs Frontend Deployment Strategy:**
    *   **Backend:** Needs a runtime environment (Java/Docker) -> Deployed to **EKS**.
    *   **Frontend:** Is static code (HTML/CSS/JS) -> Hosted on **S3** (cheaper, faster, global via CloudFront).

This guide covers the complete lifecycle from server setup to deployment, incorporating all specific snippets and corrections you requested.