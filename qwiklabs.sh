#Init
CLUSTER_NAME=onlineboutique-cluster
gcloud config set compute/zone us-central1-a
gcloud container clusters create onlineboutique-cluster --num-nodes 2 --machine-type n1-standard-2 --scopes cloud-platform --release-channel rapid --cluster-version 1.21.3-gke.1100
gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE --project $PROJECT_ID
#1
git clone https://github.com/GoogleCloudPlatform/microservices-demo.git &&
cd microservices-demo && kubectl apply -f ./release/kubernetes-manifests.yaml --namespace dev
kubectl config set-context --current --namespace dev
#2
gcloud container node-pools create optimized-pool --cluster=$CLUSTER_NAME --num-nodes=2 --machine-type=custom-2-3584
for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool=default-pool -o=name);do k cordon $node;done
gcloud container node-pools delete default-pool --cluster=$CLUSTER_NAME

#3
k create poddisruptionbudget onlineboutique-frontend-pdb --selector=app=frontend --min-available=1
k set image deployment/frontend server=gcr.io/qwiklabs-resources/onlineboutique-frontend:v2.1

#4
k autoscale deployment/frontend --min=1 --max=13 --cpu-percent=50
gcloud beta container clusters update $CLUSTER_NAME --enable-autoscaling --min-nodes 1 --max-nodes 6

k get svc
kubectl exec $(kubectl get pod --namespace=dev | grep 'loadgenerator' | cut -f1 -d ' ') -it --namespace=dev -- bash -c "export USERS=8000; locust --host="http://35.223.14.169/" --headless -u "8000" 2>&1"
k autoscale deployment/recommendationservice --min=1 --max=5 --cpu-percent=50

#Optional
gcloud container clusters update $CLUSTER_NAME \
    --enable-autoprovisioning \
    --min-cpu 1 \
    --min-memory 2 \
    --max-cpu 45 \
    --max-memory 160

cat << EOF > recommendation-vpa.yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: recommendation-vpa
spec:
  targetRef:
    apiVersion: "apps/v1"
    kind:       Deployment
    name:       recommendationservice
  updatePolicy:
    updateMode: "Auto"
EOF


---
#init
cat << EOF >> ~/.bashrc
alias k="kubectl"
alias kgp="kubectl get pods"
alias kgs="kubectl get svc"
alias kgd="kubectl get deployment"
alias kdesc="kubectl describe"
EOF
source ~/.bashrc
gcloud config set compute/zone us-east1-b
gcloud container clusters create my-cluster --num-nodes 2 --machine-type n1-standard-1 --scopes=cloud-source-repos,cloud-platform
gcloud source repos clone valkyrie-app
#1
docker build -t valkyrie-app:v0.0.1 .
#2
docker run -itd -p 8080:8080 valkyrie-app:v0.0.1  > /dev/null &
#3
gcloud source create default
docker tag valkyrie-app:v0.0.1 gcr.io/${DEVSHELL_PROJECT_ID}/valkyrie-app:v0.0.1
docker push gcr.io/${DEVSHELL_PROJECT_ID}/valkyrie-app:v0.0.1
sed -i 's#IMAGE_HERE#'gcr.io/qwiklabs-gcp-04-6eccbc3fd2c9/valkyrie-app:v0.0.1'#g' k8s/*
kubectl scale deploy/valkyrie-dev --replicas=3

###GIT
git remote add origin https://source.developers.google.com/p/$DEVSHELL_PROJECT_ID/r/default
git config --global user.email "[EMAIL_ADDRESS]"
git config --global user.name "[USERNAME]"
###


---
#Challenge lab
#Init
gcloud config set compute/region us-central1
gcloud config set compute/zone us-central1-c
gcloud container clusters create my-cluster --num-nodes 2 --machine-type n1-standard-4 --zone us-central1-c --enable-network-policy \
   --enable-binauthz
--enable-pod-security-policy


#2
gcloud sql instances create mydb \
--database-version=MYSQL_5_7 \
--cpu=2 \
--memory=7680MB \
--region=us-central1 \
--database-flags=cloudsql_iam_authentication=on \
--root-password=password123

gcloud sql databases create wordpress --instance mydb


gcloud sql users set-password wordpress \
--host=% \
--instance mydb \
--password password

# gcloud sql instances patch mydb \
# --database-flags=cloudsql_iam_authentication=on

gcloud iam service-accounts create db-wordpress \
    --description="wordpress" \
    --display-name="db-wordpress"

gcloud projects add-iam-policy-binding ${DEVSHELL_PROJECT_ID} \
    --member="serviceAccount:db-wordpress@${DEVSHELL_PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/cloudsql.client"

# gcloud sql users create "db-wordpress@${DEVSHELL_PROJECT_ID}.iam.gserviceaccount.com" \
# --instance=mydb \
# --type=cloud_iam_service_account

gcloud iam service-accounts keys create key.json \
    --iam-account=db-wordpress@${DEVSHELL_PROJECT_ID}.iam.gserviceaccount.com
#Test
gcloud beta sql connect mydb --user=wordpress --password=P@ssw0rd
gcloud sql instances describe mydb
#
Enable Cloud SQL Admin API
kubectl create secret generic cloudsql-instance-credentials --from-file key.json

kubectl create secret generic cloudsql-db-credentials \
    --from-literal username=wordpress \
    --from-literal password='password'
sed -i s/INSTANCE_CONNECTION_NAME/${DEVSHELL_PROJECT_ID}:us-central1:mydb/g wordpress.yaml
kubectl create -f volume.yaml
kubectl apply -f wordpress.yaml

#3
# helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
# helm repo update

# helm install ingress-nginx ingress-nginx/ingress-nginx
helm repo add stable https://charts.helm.sh/stable
helm repo update

helm install nginx-ingress stable/nginx-ingress
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v0.16.0/cert-manager.yaml


#psp
kubectl create clusterrolebinding clusteradmin --clusterrole=cluster-admin --user="$(gcloud config list account --format 'value(core.account)')"
kubectl create clusterrolebinding cluster-admin-binding \
--clusterrole=cluster-admin \
--user=$(gcloud config get-value core/account)
sed -i s/LAB_EMAIL_ADDRESS/db-wordpress@${DEVSHELL_PROJECT_ID}.iam.gserviceaccount.com/g issuer.yaml

gcloud iam service-accounts create demo-developer
MYPROJECT=$(gcloud config list --format 'value(core.project)')
gcloud projects add-iam-policy-binding "${MYPROJECT}" --role=roles/container.developer --member="serviceAccount:demo-developer@${MYPROJECT}.iam.gserviceaccount.com"
gcloud iam service-accounts keys create key.json --iam-account "demo-developer@${MYPROJECT}.iam.gserviceaccount.com"
gcloud auth activate-service-account --key-file=key.json
gcloud container clusters get-credentials simplecluster --zone $MY_ZONE
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: hostpath
spec:
  containers:
  - name: hostpath
    image: google/cloud-sdk:latest
    command: ["/bin/bash"]
    args: ["-c", "tail -f /dev/null"]
    volumeMounts:
    - mountPath: /rootfs
      name: rootfs
  volumes:
  - name: rootfs
    hostPath:
      path: /
EOF