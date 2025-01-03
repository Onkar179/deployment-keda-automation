# Kubernetes Automation Script

This repository contains a Bash script designed to automate various Kubernetes tasks, including managing KEDA (Kubernetes Event-Driven Autoscaling), creating deployments, exposing services, managing horizontal pod autoscalers (HPAs), and checking the health of deployments. The script leverages `kubectl` and `helm` to manage Kubernetes resources, including KEDA for autoscaling.

## Script Overview

The script contains a series of functions that can be invoked through command-line arguments. The commands primarily work with Kubernetes resources like deployments, services, HPAs, and KEDA, along with Helm charts for managing KEDA installation and upgrades.


## Prerequisites

- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) installed and configured to interact with a Kubernetes cluster.
- [Helm](https://helm.sh/docs/intro/install/) installed.
- [yq](https://github.com/mikefarah/yq) installed for reading YAML configuration files

### Command Options

The script accepts the following commands and arguments:

- **`connect`**  
    Connects to the Kubernetes cluster using `kubectl`.  
    Checks if `kubectl` is properly configured and can access the cluster.

- **`install-keda`**  
    Installs KEDA in the cluster if not already installed.  
    Optionally accepts a values file to configure the installation.

- **`upgrade-keda <values_file>`**  
    Upgrades KEDA using the provided Helm values file.

- **`create-deployment <config_file>`**  
    Creates Kubernetes deployments based on a provided configuration file.  
    The config file should define deployment details like name, image, namespace, ports, and resource requests/limits.

- **`expose-services <config_file>`**  
    Exposes services for deployments via `LoadBalancer`, as described in the configuration file.

- **`create-hpa <config_file> <deployment_name> <namespace>`**  
    Creates Horizontal Pod Autoscalers (HPAs) for a specific deployment as defined in the configuration file.

- **`check-health <deployment_name> <namespace>`**  
    Checks the health of a specific deployment and its resource utilization.

- **`-h` or `--help`**  
    Displays help information for the script.

### Helper Functions

- **`show_help()`**  
    Displays usage instructions for the script, including available commands and examples.

- **`connect_cluster()`**  
    Ensures that the script can connect to the Kubernetes cluster using `kubectl`.

- **`install_helm()`**  
    Verifies if Helm is installed, which is required for managing KEDA installation and upgrades.

- **`install_keda()`**  
    Installs KEDA in the Kubernetes cluster using Helm. It checks whether KEDA is already installed and installs it if necessary.

- **`upgrade_keda()`**  
    Upgrades an existing KEDA installation using Helm and a provided values file.

- **`create_deployment()`**  
    Creates Kubernetes deployments as per the configurations specified in the provided YAML file.

- **`create_hpa()`**  
    Creates Horizontal Pod Autoscalers (HPAs) using the configuration defined in the provided YAML file.

- **`expose_services()`**  
    Exposes services for deployments via `LoadBalancer` service type.

- **`check_health_status()`**  
    Retrieves the health status of a deployment and checks the resource utilization of its pods.

### Config File Format

For commands like `create-deployment`, `create-hpa`, and `expose-services`, a YAML configuration file is required. The config file structure is as follows:

#### Deployment Configuration Example (`deployment-config.yaml`)

```yaml
deployments:
  - name: my-app
    image: my-app-image:latest
    namespace: default
    port: 8080
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "200m"
        memory: "256Mi"

autoscalers:
  - deployment: my-app
    namespace: default
    minReplicas: 1
    maxReplicas: 5
    metric:
      type: Resource
      value: "80"
      metricType: Utilization

services:
  - name: my-app
    namespace: default
    port: 8080

```

### Run the Script:

After setting up the prerequisites, you can use the script to perform various operations on your Kubernetes cluster.

#### Example Commands:

- **Connect to the Kubernetes cluster:**

    ```bash
    ./script.sh connect
    ```

- **Install KEDA:**

    This will install KEDA in your Kubernetes cluster:

    ```bash
    ./script.sh install-keda
    ```

- **Upgrade KEDA:**

    If you need to upgrade KEDA, you can use the following command, passing a values file:

    ```bash
    ./script.sh upgrade-keda values.yaml
    ```

- **Create Deployments:**

    You can create deployments with the following command by providing a deployment configuration YAML file:

    ```bash
    ./script.sh create-deployment config.yaml
    ```

- **Expose Services:**

    To expose services for your deployments via LoadBalancer, use this command:

    ```bash
    ./script.sh expose-services service-config.yaml
    ```

- **Create Horizontal Pod Autoscalers (HPA):**

    To create HPAs for a specific deployment, use the following command:

    ```bash
    ./script.sh create-hpa config.yaml my-deployment my-namespace
    ```

- **Check Health Status:**

    To check the health status and resource utilization for a given deployment, run:

    ```bash
    ./script.sh check-health my-deployment my-namespace
    ```

### Additional Notes:

- Ensure that your Kubernetes cluster is configured properly with `kubectl` and Helm is installed and accessible.
- The script requires YAML configuration files for deployment, service, and HPA management.
- For help with available commands and usage, run:

    ```bash
    ./script.sh --help
    ```

## Error Handling

The script ensures that:

- **Valid Arguments**: Appropriate arguments are passed for each command.
- **Missing Files**: If a required argument or configuration file is missing, the script will exit with an error message.
- **Operation Failures**: If any Kubernetes or Helm operation fails, the script will exit with an error message and stop further execution to prevent cascading failures.

## Features

#### 1. **KEDA Installation & Management**
   - Easily install and manage KEDA for event-driven autoscaling in your Kubernetes cluster using Helm.

#### 2. **Deployment Management**
   - Create and manage Kubernetes deployments with resource requests, limits, and autoscaling configurations for efficient resource utilization.

#### 3. **Service Exposure**
   - Automatically expose services for your deployments, making them accessible to external traffic.

#### 4. **Health Monitoring**
   - Check the health and resource utilization of specific deployments and their pods, ensuring they are running as expected.

#### 5. **Modular Architecture**
   - Functions are designed to be modular and reusable, making it easy to adapt the script to various Kubernetes deployment scenarios.

#### 6. **Configuration via YAML**
   - Simplified configuration management using YAML files for defining deployments, services, and autoscaling (HPA) parameters, allowing for easy configuration changes.



## Design Overview

This script automates common Kubernetes tasks using `Helm` and `kubectl`. It supports tasks such as installing and upgrading KEDA, creating deployments, exposing services, managing Horizontal Pod Autoscalers (HPAs), and checking the health of deployments. The script is designed with robustness, ease of use, and flexibility in mind.

### Key Design Choices

#### **1. Error Handling with `set -euo pipefail`**
To ensure the script behaves predictably and fails early in case of errors, the following shell options are used:
- **`set -e`**: Exits the script immediately if any command fails.
- **`set -u`**: Treats unset variables as errors.
- **`set -o pipefail`**: Ensures that the script exits if any command in a pipeline fails, even if it's not the last one.

These error-handling practices ensure the script fails early and clearly if there are issues, preventing unintended actions or ambiguous results.

#### **2. Modular Function Design**
Each major task (e.g., installing KEDA, creating deployments, exposing services) is encapsulated in a dedicated function. This modular approach:
- Improves readability.
- Allows easy extension or modification of the script.
- Keeps the code organized and maintainable.

#### **3. Flexible Command Handling**
The script supports multiple commands (`connect`, `install-keda`, `upgrade-keda`, etc.), each corresponding to a specific Kubernetes task. Key features include:
- Argument validation to ensure users provide the necessary input, such as configuration files or namespaces.
- The main function interprets the command and calls the corresponding function for execution.

#### **4. Configuration via YAML**
YAML files are used to define Kubernetes resources like deployments, services, and autoscalers. This provides several benefits:
- Flexibility in configuration.
- Simplifies the addition of new configurations without needing to hardcode values.
- The script uses `yq`, a YAML processor, to read and parse YAML files.

Configuration files typically include:
- Deployment configurations.
- Resource requests and limits.
- Horizontal Pod Autoscaler (HPA) specifications.

#### **5. Helm and kubectl Integration**
The script integrates with:
- **Helm** for managing KEDA installation and upgrades. If KEDA is not installed, the script automatically installs it using Helm.
- **kubectl** to interact with the Kubernetes cluster for tasks like checking deployment status and exposing services.

#### **6. Health Monitoring and Resource Utilization**
A health-checking function uses `kubectl get deployment` and `kubectl top pods` to:
- Query the status of deployments.
- Check resource utilization, providing valuable feedback on the health of Kubernetes resources.

#### **7. Validation and Error Handling in Configuration Files**
To ensure smooth execution, the script validates configuration files for missing or invalid fields (e.g., missing namespaces or images in deployment configurations). If there are errors:
- The script outputs clear error messages.
- The problematic action is skipped to prevent unintended failures.

#### **8. Help and Documentation**
The script includes a **`show_help`** function that provides easy access to the available commands and their syntax. This helps users unfamiliar with the script quickly understand its usage. Additionally:
- The script outputs meaningful error messages when incorrect arguments are provided or when failures occur, guiding users to resolve issues.


