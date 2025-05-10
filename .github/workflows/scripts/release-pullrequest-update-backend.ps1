param (
    [string]$source_environment,
    [string]$target_environment
)

$ErrorActionPreference = "Stop"

Write-Host "Starting Updating Backend Services for PR from $source_environment to $target_environment"

$environments = Get-Content -Path ".github/workflows/config/environments.json" | ConvertFrom-Json
$backendComponents = Get-Content -Path ".github/workflows/config/components.json" | ConvertFrom-Json | Where-Object { $_.componentType -eq "backend" }

$sourceEnvironmentFolderName = ($environments | Where-Object { $_.environment -eq $source_environment }).environmentFolderName
$sourceClusterFolderName = ($environments | Where-Object { $_.environment -eq $source_environment }).clusterFolderName

if (-not $sourceEnvironmentFolderName) {
    Write-Host "Source environment `"$source_environment`" not found in environments.json"
    exit 1
}

$targetEnvironmentFolderName = ($environments | Where-Object { $_.environment -eq $target_environment }).environmentFolderName
$targetClusterFolderName = ($environments | Where-Object { $_.environment -eq $target_environment }).clusterFolderName

if (-not $targetClusterFolderName) {
    Write-Host "Target environment `"$target_environment`" not found in environments.json"
    exit 1
}

$results = @()

foreach ($backendComponent in $backendComponents) {
    $componentFolderName = $backendComponent.componentFolderName

    $sourceServiceFolder = "overlays/$sourceEnvironmentFolderName/$sourceClusterFolderName/$componentFolderName"
    $targetServiceFolder = "overlays/$targetEnvironmentFolderName/$targetClusterFolderName/$componentFolderName"

    if (-not (Test-Path -Path $sourceServiceFolder -PathType Container)) {
        Write-Host "Source folder `"$sourceServiceFolder`" does not exist"
        exit 1
    }

    # If the target folder does not exist, create it
    if (-not (Test-Path -Path $targetServiceFolder -PathType Container)) {
        Write-Host "Target folder `"$targetServiceFolder`" does not exist. Creating it..."
        New-Item -Path $targetServiceFolder -ItemType Directory
    }

    $sourceKustomizationFile = "$sourceServiceFolder/kustomization.yaml"
    $targetKustomizationFile = "$targetServiceFolder/kustomization.yaml"

    # Get all images from the source kustomization.yaml file
    $sourceImages = yq e '.images' -o=json $sourceKustomizationFile | ConvertFrom-Json

    # Loop through each image in the source and update the corresponding image in the target
    foreach ($sourceImage in $sourceImages) {
        $sourceImageName = $sourceImage.name
        $sourceNewTag = $sourceImage.newTag
        $updated = ""

        try {
            # Check if the image exists in the target kustomization file
            $existingDockerImage = yq eval ".images[] | select(.name == `"$sourceImageName`")" -o=json $targetKustomizationFile | ConvertFrom-Json

            if (-not $existingDockerImage) {
                Write-Host "Image $sourceImageName not found in $targetKustomizationFile"
            } else {
                # Only update the newTag if it is different from the source
                if ($existingDockerImage.newTag -ne $sourceNewTag) {
                    yq eval "(.images[] | select(.name == `"$sourceImageName`")).newTag = `"$sourceNewTag`"" -i $targetKustomizationFile
                    Write-Host "$sourceImageName newTag updated to $sourceNewTag"
                    $updated = ":green_circle:"
                } else {
                    Write-Host "$sourceImageName newTag is already $sourceNewTag. No update needed."
                }
            }
        } catch {
            Write-Host "Error updating $sourceImageName to newTag $($sourceNewTag): $_"
        }

        $results += [pscustomobject]@{
            serviceName = $backendComponent.componentName
            gitHubRepository = $backendComponent.gitHubRepository
            version = $sourceNewTag
            currentVersion = $existingDockerImage.newTag
            updated = $updated
        }
    }
}

# Convert results to compressed JSON
$resultsJson = $results | ConvertTo-Json -Compress -AsArray -Depth 10

# Write the results to a file
return $resultsJson
