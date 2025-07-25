#!/bin/bash
set -e

# A list of all services to update
SERVICES=("cart" "catalog" "checkout" "orders" "ui")
TAG="1.2.2"

echo "Updating values.yaml files to use public ECR images..."

# Function to detect OS and use appropriate sed command
sed_inplace() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS requires backup extension (using empty string)
    sed -i '' "$@"
  else
    # Linux doesn't require backup extension
    sed -i "$@"
  fi
}

for SERVICE in "${SERVICES[@]}"; do
  FILE_PATH="src/${SERVICE}/chart/values.yaml"
  PUBLIC_REGISTRY="public.ecr.aws/aws-containers/retail-store-sample-${SERVICE}"

  if [ -f "$FILE_PATH" ]; then
    echo "Processing ${FILE_PATH}..."
    
    # Using sed to replace the repository and tag lines.
    # The | separator is used to avoid issues with slashes in the path.
    sed_inplace "s|^  repository:.*|  repository: ${PUBLIC_REGISTRY}|" "$FILE_PATH"
    sed_inplace "s|^  tag:.*|  tag: \"${TAG}\"|" "$FILE_PATH"
    
    echo "Updated ${FILE_PATH}"
    echo "   Repository: ${PUBLIC_REGISTRY}"
    echo "   Tag: ${TAG}"
    echo ""
  else
    echo "ERROR: File not found at ${FILE_PATH}"
    exit 1
  fi
done

echo "All services updated successfully!"
echo ""
echo "Updated services:"
for SERVICE in "${SERVICES[@]}"; do
  echo "  - ${SERVICE}: public.ecr.aws/aws-containers/retail-store-sample-${SERVICE}:${TAG}"
done