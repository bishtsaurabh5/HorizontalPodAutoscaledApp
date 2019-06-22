#!/bin/bash

echo "Remember this script is a stateful script ..which means that you need to provision cluster everytime you run ...since it does not store ip of loadbalancer"
echo "You are free to tweak this script as per your needs :)"
staging_hostname="staging-guestbook.mstakx.io"
production_hostname="guestbook.mstakx.io"
nsarray=("staging" "production")

provisionCluster() {
 #provision cluster using terraform
  cd terraform
  terraform init -input=false 
  terraform plan -out=tfplan -input=false
  terraform apply -input=false "tfplan"
  project_name=$(cat terraform.tfstate | jq -r '.resources[0].instances[0].attributes.project')
  project_zone=$(cat terraform.tfstate | jq -r '.resources[0].instances[0].attributes.zone')
  cluster_name=$(cat terraform.tfstate | jq -r '.outputs.gcp_cluster_name.value')
  gcloud container clusters get-credentials $cluster_name --zone $project_zone --project $project_name
  cd ..
  
}

deployApplication() {  
   kubectl apply -f guestbook-app/guestbook-complete.yaml
   sleep 10s
}

setupIngressControllerAndRouting() {
curl -o get_helm.sh https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get
chmod +x get_helm.sh
./get_helm.sh

kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller

sleep 25s
helm install --name nginx-ingress stable/nginx-ingress --set rbac.create=true --set controller.publishService.enabled=true

sleep 60s
echo "wait sometime so that loadbalancer is allocated ip"

frontendstagingip=$(kubectl -n staging get svc frontend -o=jsonpath='{.spec.clusterIP}')
frontendproductionip=$(kubectl -n production get svc frontend -o=jsonpath='{.spec.clusterIP}')

sed -e "s/\${frontendstagingip}/$frontendstagingip/" -e "s/\${frontendproductionip}/$frontendproductionip/" DaemonSetForHost/DaemonSet.yaml | tee ds.yaml

kubectl apply -f ds.yaml
kubectl apply -f ingress/production-ingress.yaml
kubectl apply -f ingress/staging-ingress.yaml
rm -rf ds.yaml

loadBalancerip=$(kubectl get svc nginx-ingress-controller -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo $loadBalancerip
echo "$loadBalancerip  $staging_hostname $production_hostname" >> /etc/hosts

}

setupAutoscaler()
{
kubectl -n staging autoscale deployment frontend --cpu-percent=10 --min=1 --max=10
kubectl -n production autoscale deployment frontend --cpu-percent=10 --min=1 --max=10
}

setupLoadConfig()
{
  sed -e "s/\${load-balancer-ip}/$loadBalancerip/" -e "s/\${hostname}/$staging_hostname/" -e "s/\${namespace}/staging/" load-generator-deployment/load-generator-spec.yaml | tee load-generator-staging.yaml
  sed -e "s/\${load-balancer-ip}/$loadBalancerip/" -e "s/\${hostname}/$production_hostname/" -e "s/\${namespace}/production/" load-generator-deployment/load-generator-spec.yaml | tee load-generator-production.yaml
 kubectl apply -f load-generator-staging.yaml
 kubectl apply -f load-generator-production.yaml
}

increaseLoad()
{
  kubectl -n $ns scale deployment load-generator-deployment-$ns --replicas=5
}

decreaseLoad()
{
  kubectl -n $ns scale deployment load-generator-deployment-$ns --replicas=1
}

stopLoad()
{
   kubectl -n $ns delete deploy load-generator-deployment-$ns
}

viewScaling()
{
  watch -n 5 "kubectl -n $ns get hpa"
}

checkNamespace()
{
 while true
 echo  "Enter namespace"
 read ns
 do
 if [[ " ${nsarray[@]} " =~ " ${ns} " ]]; then
	 break
     fi
 echo "Namespace not present ...Please enter staging or production namespace"
 done
}

destroyProvisionedCluster() {
   cd terraform
   terraform destroy
   cd ..
}

startLoadMenu() {
setupLoadConfig
checkNamespace
while true
do
echo "Enter your choice"
echo "1. start Load"
echo "2. decrease Load"
echo "3. watch Horizontal Pod Scaling in play"
echo "4. stop Load"
echo "5. Exit"
read opt
case $opt in
     "1")
             increaseLoad
	     ;;
     "2")
             decreaseLoad
	     ;;
     "3") 
	     viewScaling
	     ;;
     "4")    
	     stopLoad
	     ;;
     "5")   
	     break
	     ;;
     *)     
	      echo "Invalid choice"
	      ;;
esac
done
}

while true
do
echo "Enter your choice"
echo "1. Provision your GCP Cluster"
echo "2. Deploy pods and services on the Cluster"
echo "3. Setup Ingress Networking and Load Balancer"
echo "4. Setup Horizontal Pod Autoscaler"
echo "5. Perform above steps(1-4) in one go "
echo "6. Start Load testing"
echo "7. Destroy Cluster"
echo "8. Exit"
read opt
case $opt in
	"1")
		provisionCluster
		;;
	"2")
		deployApplication
		;;
	 "3")   
		 setupIngressControllerAndRouting
		;;
	 "4")   
		 setupAutoscaler
		 ;;
         "5")
		 provisionCluster
		 deployApplication
		 setupIngressControllerAndRouting
		 setupAutoscaler
		 ;;
	  "6")   
		  startLoadMenu
		  ;;

	  "7") 
                  destroyProvisionedCluster
		  ;;
	  "8")   
		  break
		  ;;
		  
	   *)     echo "Invalid Option"
esac 
done	    




