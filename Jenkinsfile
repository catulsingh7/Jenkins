pipeline {
    agent any
    tools {
        maven "maven3.9"
    }

    environment {
        IMAGE_REPOSITORY = "221082191413.dkr.ecr.us-east-1.amazonaws.com"
        IMAGE_NAME = "devopscheetah"
        DEPLOYMENT_NAME = "frontend"
        CLUSTER_NAME = "EKS-Cluster"
        GIT_REPO_NAME = "Jenkins"
        REGION = "us-east-1"
    }

    stages {
        stage ('fetch code'){
            steps {
                git branch: 'atom', url: 'https://github.com/catulsingh7/Jenkins.git'
            }

        }
        stage('unit test') {
            steps {
                sh 'mvn test'
            }
        }
        stage('build') {
            steps {
                sh 'mvn install -DskipTests'
            }

            post {
                success {
                    echo "Now archiving the code"
                    archiveArtifacts artifacts: '**/target/*.war'
                }
            }
        }
        stage ('checkstyle anaylsis') {
            steps {
                sh 'mvn checkstyle:checkstyle'
            }
        }
         
        
        stage("Upload artifacts") {
            steps {
                        nexusArtifactUploader(
                            nexusVersion: 'nexus3',
                            protocol: 'http',
                            nexusUrl: '54.198.223.73:8081',
                            groupId: 'dev',
                            version: "${env.BUILD_ID}",
                            repository: 'test-repo',
                            credentialsId: 'nexus_credentials',
                            artifacts: [
                                [artifactId: 'devopscheetah',
                                classifier: '',
                                file: 'target/vprofile-v2.war',
                                type: 'war'],
                            ]
                        );
                 }
            }
        stage('CODE ANALYSIS with SONARQUBE') {
          
		  environment {
             scannerHome = tool 'newsonarserver'
          }

          steps {
            withSonarQubeEnv('jenkins-sonar-secret') {
               sh '''${scannerHome}/bin/sonar-scanner -Dsonar.projectKey=devopscheetah \
                   -Dsonar.projectName=devopscheetah-repo \
                   -Dsonar.projectVersion=1.0 \
                   -Dsonar.sources=src/ \
                   -Dsonar.java.binaries=target/test-classes/com/visualpathit/account/controllerTest/ \
                   -Dsonar.junit.reportsPath=target/surefire-reports/ \
                   -Dsonar.jacoco.reportsPath=target/jacoco.exec \
                   -Dsonar.java.checkstyle.reportPaths=target/checkstyle-result.xml'''
            }
	    timeout(time: 10, unit: 'MINUTES') {
   	    	script {
                	def qualityGate = waitForQualityGate()
                	if (qualityGate.status != 'OK') {
                    	error "❌ SonarQube Quality Gate Failed: ${qualityGate.status}"
                }
            }
		    
	  }
          }
	}
        stage ("AWS Login") {
            steps {
                script {
                    sh 'aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${IMAGE_REPOSITORY}'
                    sh 'aws eks update-kubeconfig --region us-east-1 --name ${CLUSTER_NAME}'
                }
            }
        }

        stage ("Build Docker Image") {
            steps {
                script {
                sh 'docker build -t ${IMAGE_NAME}:${BUILD_NUMBER} -f Dockerfile .'
                sh 'docker tag ${IMAGE_NAME}:${BUILD_NUMBER} 221082191413.dkr.ecr.us-east-1.amazonaws.com/devopscheetah:v-${BUILD_NUMBER}'
            }
            }
        }

        stage ("Push Docker Image to ECR") {
            steps {
                sh 'docker push ${IMAGE_REPOSITORY}/${IMAGE_NAME}:v-${BUILD_NUMBER}'
            }
        }


        stage ("Deploy Image to EKS") {
                steps {
                    sh "kubectl set image deployment/${DEPLOYMENT_NAME} ${DEPLOYMENT_NAME}=${IMAGE_REPOSITORY}/${IMAGE_NAME}:v-${BUILD_NUMBER} -n devopscheetah"
                }
            }
    }
}



