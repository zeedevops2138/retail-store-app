#!/bin/bash

# Industry-Standard Container Image Build and Tagging Script
# Follows best practices from Docker, AWS, and container registries

set -euo pipefail

# Configuration
AWS_REGION="${AWS_REGION:-eu-west-1}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-565393041505}"
ECR_BASE_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Services to build
SERVICES=("cart" "catalog" "checkout" "orders" "ui")

# Get build metadata
GIT_COMMIT=$(git rev-parse --short HEAD)
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BUILD_ID=$(date +%s)
VERSION=${VERSION:-"1.0.0"}

echo "🏗️  Starting Industry-Standard Container Build Process"
echo "=================================================="
echo "Git Commit: ${GIT_COMMIT}"
echo "Git Branch: ${GIT_BRANCH}"
echo "Build Date: ${BUILD_DATE}"
echo "Build ID: ${BUILD_ID}"
echo "Version: ${VERSION}"
echo "ECR Base URL: ${ECR_BASE_URL}"
echo "=================================================="

# Function to build and tag a single service
build_and_tag_service() {
    local service=$1
    local service_dir="src/${service}"
    local image_name="retail-store-sample-${service}"
    local ecr_repo="${ECR_BASE_URL}/${image_name}"
    
    echo ""
    echo "🔨 Building ${service} service..."
    echo "Service Directory: ${service_dir}"
    echo "ECR Repository: ${ecr_repo}"
    
    # Build the image
    docker build \
        --build-arg BUILD_DATE="${BUILD_DATE}" \
        --build-arg GIT_COMMIT="${GIT_COMMIT}" \
        --build-arg VERSION="${VERSION}" \
        --label "org.opencontainers.image.created=${BUILD_DATE}" \
        --label "org.opencontainers.image.revision=${GIT_COMMIT}" \
        --label "org.opencontainers.image.version=${VERSION}" \
        --label "org.opencontainers.image.source=https://github.com/iemafzalhassan/retail-store-sample-app" \
        --label "org.opencontainers.image.title=Retail Store $(echo ${service} | sed 's/.*/\u&/') Service" \
        --label "org.opencontainers.image.description=Microservice for retail store ${service} functionality" \
        --label "build.id=${BUILD_ID}" \
        --label "build.branch=${GIT_BRANCH}" \
        -t "${image_name}:build" \
        "${service_dir}"
    
    echo "✅ Built ${service} successfully"
    
    # Apply industry-standard tags
    echo "🏷️  Applying tags for ${service}..."
    
    # 1. Semantic Version (immutable)
    docker tag "${image_name}:build" "${ecr_repo}:v${VERSION}"
    echo "   ✓ Semantic Version: v${VERSION}"
    
    # 2. Git Commit (immutable, traceable)
    docker tag "${image_name}:build" "${ecr_repo}:git-${GIT_COMMIT}"
    echo "   ✓ Git Commit: git-${GIT_COMMIT}"
    
    # 3. Build ID (immutable, CI/CD correlation)
    docker tag "${image_name}:build" "${ecr_repo}:build-${BUILD_ID}"
    echo "   ✓ Build ID: build-${BUILD_ID}"
    
    # 4. Branch-based tag (mutable, environment correlation)
    docker tag "${image_name}:build" "${ecr_repo}:${GIT_BRANCH}"
    echo "   ✓ Branch: ${GIT_BRANCH}"
    
    # 5. Latest for main branch (mutable, convenience)
    if [[ "${GIT_BRANCH}" == "main" ]]; then
        docker tag "${image_name}:build" "${ecr_repo}:latest"
        echo "   ✓ Latest: latest"
    fi
    
    # 6. Combined tag for uniqueness (recommended for production)
    docker tag "${image_name}:build" "${ecr_repo}:${GIT_BRANCH}-${GIT_COMMIT}"
    echo "   ✓ Combined: ${GIT_BRANCH}-${GIT_COMMIT}"
    
    echo "✅ Tagged ${service} with industry-standard tags"
}

# Function to push images to ECR
push_to_ecr() {
    local service=$1
    local image_name="retail-store-sample-${service}"
    local ecr_repo="${ECR_BASE_URL}/${image_name}"
    
    echo ""
    echo "📤 Pushing ${service} to ECR..."
    
    # Push all tags
    docker push "${ecr_repo}:v${VERSION}"
    docker push "${ecr_repo}:git-${GIT_COMMIT}"
    docker push "${ecr_repo}:build-${BUILD_ID}"
    docker push "${ecr_repo}:${GIT_BRANCH}"
    docker push "${ecr_repo}:${GIT_BRANCH}-${GIT_COMMIT}"
    
    if [[ "${GIT_BRANCH}" == "main" ]]; then
        docker push "${ecr_repo}:latest"
    fi
    
    echo "✅ Pushed ${service} to ECR successfully"
}

# Function to update Helm values
update_helm_values() {
    local service=$1
    local tag="${GIT_BRANCH}-${GIT_COMMIT}"
    local values_file="src/${service}/chart/values.yaml"
    
    echo "📝 Updating Helm values for ${service}..."
    echo "   File: ${values_file}"
    echo "   Tag: ${tag}"
    
    # Use yq to update the image tag
    if command -v yq &> /dev/null; then
        yq eval ".image.tag = \"${tag}\"" -i "${values_file}"
        yq eval ".image.repository = \"${ECR_BASE_URL}/retail-store-sample-${service}\"" -i "${values_file}"
    else
        # Fallback to sed
        sed -i.bak "s|tag: \".*\"|tag: \"${tag}\"|" "${values_file}"
        sed -i.bak "s|repository: .*|repository: ${ECR_BASE_URL}/retail-store-sample-${service}|" "${values_file}"
        rm -f "${values_file}.bak"
    fi
    
    echo "✅ Updated Helm values for ${service}"
}

# Main execution
main() {
    echo "🚀 Starting build process for all services..."
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        echo "❌ Docker is not running. Please start Docker first."
        exit 1
    fi
    
    # Login to ECR
    echo "🔐 Logging into ECR..."
    aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_BASE_URL}"
    
    # Build and tag all services
    for service in "${SERVICES[@]}"; do
        build_and_tag_service "${service}"
    done
    
    # Push to ECR if requested
    if [[ "${1:-}" == "--push" ]]; then
        echo ""
        echo "📤 Pushing all images to ECR..."
        for service in "${SERVICES[@]}"; do
            push_to_ecr "${service}"
        done
        
        echo ""
        echo "📝 Updating Helm values..."
        for service in "${SERVICES[@]}"; do
            update_helm_values "${service}"
        done
        
        # Commit updated values
        echo "💾 Committing updated Helm values..."
        git add src/*/chart/values.yaml
        git commit -m "chore: update image tags to ${GIT_BRANCH}-${GIT_COMMIT}

- Built with industry-standard tagging
- Version: v${VERSION}
- Build ID: ${BUILD_ID}
- Commit: ${GIT_COMMIT}" || echo "No changes to commit"
    fi
    
    echo ""
    echo "🎉 Build process completed successfully!"
    echo ""
    echo "📋 Summary of tags created:"
    echo "   • Semantic Version: v${VERSION}"
    echo "   • Git Commit: git-${GIT_COMMIT}"
    echo "   • Build ID: build-${BUILD_ID}"
    echo "   • Branch: ${GIT_BRANCH}"
    echo "   • Combined: ${GIT_BRANCH}-${GIT_COMMIT}"
    if [[ "${GIT_BRANCH}" == "main" ]]; then
        echo "   • Latest: latest"
    fi
    echo ""
    echo "📚 Usage examples:"
    echo "   Production: ${ECR_BASE_URL}/retail-store-sample-cart:v${VERSION}"
    echo "   Development: ${ECR_BASE_URL}/retail-store-sample-cart:${GIT_BRANCH}-${GIT_COMMIT}"
    echo "   Rollback: ${ECR_BASE_URL}/retail-store-sample-cart:git-<previous-commit>"
}

# Help function
show_help() {
    echo "Industry-Standard Container Build and Tag Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --push          Build, tag, and push to ECR"
    echo "  --help          Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_REGION      AWS region (default: eu-west-1)"
    echo "  AWS_ACCOUNT_ID  AWS account ID (default: 565393041505)"
    echo "  VERSION         Semantic version (default: 1.0.0)"
    echo ""
    echo "Examples:"
    echo "  $0              # Build and tag locally only"
    echo "  $0 --push       # Build, tag, and push to ECR"
    echo "  VERSION=1.1.0 $0 --push  # Build with custom version"
}

# Parse command line arguments
case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    --push)
        main --push
        ;;
    *)
        main
        ;;
esac 