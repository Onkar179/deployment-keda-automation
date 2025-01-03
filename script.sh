#!/bin/bash

set -euo pipefail

# Constants
KEDA_NAMESPACE="keda"
HELM_REPO_NAME="kedacore"
HELM_REPO_URL="https://kedacore.github.io/charts"

# Function: Display Help
# Function: Display Help
show_help() {
  echo "Usage: $0 [COMMAND] [ARGS]"
  echo ""
  echo "Commands:"
  echo "  connect                        Connect to the Kubernetes cluster."
  echo "  install-keda                   Install KEDA if not already installed."
  echo "  update-keda <values_file>      Upgrade KEDA using the provided Helm values file or with default values if not provided."
  echo "  create-deployment <config>     Create one or more Kubernetes deployments using a configuration file."
  echo "  expose-services <config>       Expose multiple deployments via LoadBalancer services using a configuration file."
  echo "  create-hpa <config> <deployment_name> <namespace>"
  echo "                                 Create Horizontal Pod Autoscalers (HPAs) for a deployment using a configuration file."
  echo "  check-health <deployment_name> <namespace>"
  echo "                                 Check the health status of a specific deployment and view resource utilization."
  echo "  -h, --help                     Show this help message."
  echo ""
  echo "Examples:"
  echo "  $0 connect"
  echo "  $0 install-keda"
  echo "  $0 upgrade-keda values.yaml"
  echo "  $0 create-deployment deployment-config.yaml"
  echo "  $0 expose-services service-config.yaml"
  echo "  $0 create-hpa hpa-config.yaml my-deployment my-namespace"
  echo "  $0 check-health my-deployment my-namespace"
}


# Function: Connect to the Kubernetes cluster
connect_cluster() {
  echo "Connecting to Kubernetes cluster..."
  if ! kubectl cluster-info > /dev/null 2>&1; then
    echo "Error: Unable to connect to the Kubernetes cluster. Ensure kubectl is configured."
    exit 1
  fi
  echo "Successfully connected to the cluster."
}

# Function: Install Helm if not installed
install_helm() {
  echo "Checking if Helm is installed..."
  if ! command -v helm > /dev/null 2>&1; then
    echo "Helm is not installed. Installing Helm..."

    # Determine the OS type
    OS=$(uname -s)
    if [[ "$OS" == "Linux" ]]; then
      # Linux installation
      curl https://get.helm.sh/helm-v3.11.0-linux-amd64.tar.gz -o helm.tar.gz
      tar -zxvf helm.tar.gz
      mv linux-amd64/helm /usr/local/bin/helm
      rm -rf linux-amd64 helm.tar.gz
    elif [[ "$OS" == "Darwin" ]]; then
      # macOS installation
      brew install helm
    else
      echo "Unsupported OS. Please install Helm manually."
      exit 1
    fi

    echo "Helm has been installed."
  else
    echo "Helm is already installed."
  fi
}

# Function: Install KEDA
install_keda() {
  local values_file="${1:-}"

  echo "Installing KEDA..."

  # Check if KEDA is already installed
  if helm list -n "$KEDA_NAMESPACE" | grep -q "keda"; then
    echo "KEDA is already installed. Skipping installation."
    return
  fi

  # Create namespace if not exists
  kubectl create namespace "$KEDA_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

  # Add Helm repo and update
  helm repo add "$HELM_REPO_NAME" "$HELM_REPO_URL"
  helm repo update

  # Install KEDA with or without custom values
  if [[ -n "$values_file" && -f "$values_file" ]]; then
    helm install keda "$HELM_REPO_NAME/keda" \
      --namespace "$KEDA_NAMESPACE" \
      --values "$values_file" \
      --wait
  else
    helm install keda "$HELM_REPO_NAME/keda" \
      --namespace "$KEDA_NAMESPACE" \
      --wait
  fi

  # Confirm installation status
  if kubectl get pods -n "$KEDA_NAMESPACE" | grep -q 'Running'; then
    echo "KEDA has been successfully installed."
  else
    echo "Error: KEDA installation failed."
    exit 1
  fi
}


# Function: Upgrade KEDA
upgrade_keda() {
  local values_file="${1:-}"

  echo "Upgrading KEDA..."

  if helm list -n "$KEDA_NAMESPACE" | grep -q "keda"; then
    if [[ -n "$values_file" && -f "$values_file" ]]; then
      helm upgrade keda "$HELM_REPO_NAME/keda" \
        --namespace "$KEDA_NAMESPACE" \
        --values "$values_file" \
        --wait
    else
      helm upgrade keda "$HELM_REPO_NAME/keda" \
        --namespace "$KEDA_NAMESPACE" \
        --wait
    fi
    echo "KEDA has been successfully upgraded."
  else
    echo "Error: KEDA is not installed. Please install it first."
    exit 1
  fi
}

create_deployment() {
  # Check if the config file is provided
  if [ -z "${2:-}" ]; then
    echo "Error: Configuration file is required for create-deployment command."
    exit 1
  fi

  local config_file="$2"

  echo "Creating deployments using configuration file: $config_file"

  # Check if the config file exists
  if [[ ! -f "$config_file" ]]; then
    echo "Error: Configuration file $config_file not found."
    exit 1
  fi

  # Get the number of deployments
  local deployments_count=$(yq eval '.deployments | length' "$config_file")
  if [[ "$deployments_count" -eq 0 ]]; then
    echo "Error: No deployments found in the configuration file."
    exit 1
  fi

  # Iterate through deployments
  for ((i = 0; i < deployments_count; i++)); do
    local deployment_name=$(yq eval ".deployments[$i].name" "$config_file")
    local image=$(yq eval ".deployments[$i].image" "$config_file")
    local namespace=$(yq eval ".deployments[$i].namespace" "$config_file")
    local port=$(yq eval ".deployments[$i].port" "$config_file")
    local cpu_request=$(yq eval ".deployments[$i].resources.requests.cpu" "$config_file")
    local cpu_limit=$(yq eval ".deployments[$i].resources.limits.cpu" "$config_file")
    local memory_request=$(yq eval ".deployments[$i].resources.requests.memory" "$config_file")
    local memory_limit=$(yq eval ".deployments[$i].resources.limits.memory" "$config_file")

    # Validate required fields
    if [[ -z "$deployment_name" || -z "$image" || -z "$namespace" ]]; then
      echo "Error: Deployment name, image, and namespace are required. Skipping deployment $i."
      continue
    fi

    # Create namespace if it doesn't exist
    kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -

    # Create deployment
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $deployment_name
  namespace: $namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $deployment_name
  template:
    metadata:
      labels:
        app: $deployment_name
    spec:
      containers:
      - name: $deployment_name
        image: $image
        resources:
          requests:
            memory: "$memory_request"
            cpu: "$cpu_request"
          limits:
            memory: "$memory_limit"
            cpu: "$cpu_limit"
        ports:
        - containerPort: $port
EOF

    echo "Deployment $deployment_name created successfully in namespace $namespace."
  done
}

# Function: Create Horizontal Pod Autoscalers (HPA) for multiple deployments
create_hpa() {
  local config_file="$1"
  local deployment_name="$2"
  local namespace="$3"

  echo "Creating HPA for deployment: $deployment_name in namespace: $namespace using configuration: $config_file"

  if [[ ! -f "$config_file" ]]; then
    echo "Error: Configuration file $config_file not found."
    exit 1
  fi

  local autoscalers=$(yq eval '.autoscalers' "$config_file")
  if [[ -z "$autoscalers" ]]; then
    echo "Error: No autoscaler configuration found in $config_file."
    exit 1
  fi

  local autoscaler_count=$(yq eval '.autoscalers | length' "$config_file")
  for ((i = 0; i < autoscaler_count; i++)); do
    local hpa_deployment=$(yq eval ".autoscalers[$i].deployment" "$config_file")
    local hpa_namespace=$(yq eval ".autoscalers[$i].namespace" "$config_file")
    local hpa_min_replicas=$(yq eval ".autoscalers[$i].minReplicas" "$config_file")
    local hpa_max_replicas=$(yq eval ".autoscalers[$i].maxReplicas" "$config_file")
    local metric_type=$(yq eval ".autoscalers[$i].metric.type" "$config_file")
    local metric_value=$(yq eval ".autoscalers[$i].metric.value" "$config_file")
    local metric_trigger_type=$(yq eval ".autoscalers[$i].metric.metricType" "$config_file")

    if [[ -z "$metric_trigger_type" || "$metric_trigger_type" == "null" ]]; then
      metric_type="Utilization"  # Default to Utilization if not specified
    fi


    # Debugging: Print extracted values
    echo "Deployment: $hpa_deployment, Namespace: $hpa_namespace, MinReplicas: $hpa_min_replicas, MaxReplicas: $hpa_max_replicas"
    echo "Metric Type: $metric_type, Metric_Trigger_Type: $metric_trigger_type, Metric Value: $metric_value"

    # Validate required fields
    if [[ -z "$hpa_deployment" || -z "$hpa_namespace" || -z "$metric_type" || -z "$metric_value" ]]; then
      echo "Error: Missing required fields for autoscaler $i. Skipping."
      continue
    fi

    cat <<EOF | kubectl apply -f -
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: ${hpa_deployment}-scaledobject
  namespace: ${hpa_namespace}
spec:
  scaleTargetRef:
    name: ${hpa_deployment}
  minReplicaCount: ${hpa_min_replicas}
  maxReplicaCount: ${hpa_max_replicas}
  triggers:
  - type: ${metric_type}
    metadata:
      value: "${metric_value}"
      type: "${metric_trigger_type}"
EOF

    echo "HPA for deployment ${hpa_deployment} created successfully."
  done
}


# Function: Expose multiple services based on configuration
expose_services() {
  local config_file="$1"

  echo "Exposing services using configuration file: $config_file"

  if [[ ! -f "$config_file" ]]; then
    echo "Error: Configuration file $config_file not found."
    exit 1
  fi

  # Iterate over services in the configuration file
  local services_count=$(yq eval '.services | length' "$config_file")
  if [[ "$services_count" -eq 0 ]]; then
    echo "Error: No services found in the configuration file."
    exit 1
  fi

  for ((i = 0; i < services_count; i++)); do
    local service_name=$(yq eval ".services[$i].name" "$config_file")
    local namespace=$(yq eval ".services[$i].namespace" "$config_file")
    local port=$(yq eval ".services[$i].port" "$config_file")

    # Validate required fields
    if [[ -z "$service_name" || -z "$namespace" || -z "$port" ]]; then
      echo "Error: Service name, namespace, and port are required. Skipping service $i."
      continue
    fi

    echo "Exposing service: $service_name on port $port"
    kubectl expose deployment "$service_name" --type=LoadBalancer --name="$service_name-service" --port="$port" -n "$namespace"
    echo "Service $service_name exposed successfully."
  done
}


# Function: Retrieve health status
check_health_status() {
  local deployment_name="$1"
  local namespace="$2"

  echo "Checking health status for deployment: $deployment_name"

  kubectl get deployment "$deployment_name" -n "$namespace" -o wide
  echo "Checking the resources utilization of the pods"
  kubectl top pods -n "$namespace" --selector=app="$deployment_name"

  echo "Health status retrieved."
}

# Main function
main() {
  # Check if $1 is provided (the command argument)
  if [ -z "${1:-}" ]; then
    echo "Error: Command is required."
    show_help
    exit 1
  fi

  # If the command is create-deployment, ensure the second argument is provided
  if [[ "$1" == "create-deployment" && -z "${2:-}" ]]; then
    echo "Error: Configuration file is required for create-deployment command."
    exit 1
  fi

  if [[ "$1" == "expose-services" && -z "${2:-}" ]]; then
    echo "Error: Configuration file is required for expose-services command."
    exit 1
  fi

  # If the command is create-hpa, ensure the necessary arguments are provided
  if [[ "$1" == "create-hpa" ]]; then
    if [[ -z "${2:-}" || -z "${3:-}" || -z "${4:-}" ]]; then
      echo "Error: Configuration file, deployment name, and namespace are required for create-hpa command."
      exit 1
    fi
  fi

  if [[ "$1" == "check-health" ]]; then
    # Check if both deployment name and namespace are provided
    if [ -z "${2:-}" ] && [ -z "${3:-}" ]; then
      echo "Error: Deployment name and Namespace are required for check-health command."
      exit 1
    fi
    
    if [ -z "${2:-}" ]; then
      echo "Error: Deployment name is required for check-health command."
      exit 1
    fi
    
    if [ -z "${3:-}" ]; then
      echo "Error: Namespace is required for check-health command."
      exit 1
    fi
  fi

  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
  fi

  case "$1" in
    connect)
      connect_cluster
      ;;
    install-keda)
      install_helm
      connect_cluster
      install_keda "${2:-}"
      ;;
    upgrade-keda)
      install_helm
      connect_cluster
      upgrade_keda "${2:-}"
      ;;
    create-deployment)
      create_deployment "$@"
      ;;
    expose-services)
      expose_services "$2"
      ;;
    create-hpa)
      create_hpa "$2" "$3" "$4"
      ;;
    check-health)
      check_health_status "$2" "$3"
      ;;
    *)
      echo "Error: Invalid command. Use -h or --help for usage instructions."
      exit 1
      ;;
  esac
}

main "$@"

