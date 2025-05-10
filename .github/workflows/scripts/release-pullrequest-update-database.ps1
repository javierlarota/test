param (
    [string]$source_environment,
    [string]$target_environment
)

$ErrorActionPreference = "Stop"

Write-Host "Starting Updating Database Services for PR from $source_environment to $target_environment"

$environments = Get-Content -Path ".github/workflows/config/environments.json" | ConvertFrom-Json
$components = Get-Content -Path ".github/workflows/config/components.json" | ConvertFrom-Json | Where-Object { $_.componentType -eq "database" }

$sourceEnvironmentFolderName = ($environments | Where-Object { $_.environment -eq $source_environment }).environmentFolderName
$sourceRegionShortName = ($environments | Where-Object { $_.environment -eq $source_environment }).regionShortName

if (-not $sourceEnvironmentFolderName) {
    Write-Host "Source environment `"$source_environment`" not found in environments.json"
    exit 1
}

$targetEnvironmentFolderName = ($environments | Where-Object { $_.environment -eq $target_environment }).environmentFolderName
$targetRegionShortName = ($environments | Where-Object { $_.environment -eq $target_environment }).regionShortName

if (-not $targetRegionShortName) {
    Write-Host "Target environment `"$target_environment`" not found in environments.json"
    exit 1
}

$results = @()

foreach ($component in $components) {
    $componentFolderName = $component.componentFolderName

    $sourceComponentFolder = "database/$sourceEnvironmentFolderName/$sourceRegionShortName/$componentFolderName"
    $targetComponentFolder = "database/$targetEnvironmentFolderName/$targetRegionShortName/$componentFolderName"

    if (-not (Test-Path -Path $sourceComponentFolder -PathType Container)) {
        Write-Host "Source folder `"$sourceComponentFolder`" does not exist"
        exit 1
    }

    # If the target folder does not exist, create it
    if (-not (Test-Path -Path $targetComponentFolder -PathType Container)) {
        Write-Host "Target folder `"$targetComponentFolder`" does not exist. Creating it..."
        New-Item -Path $targetComponentFolder -ItemType Directory
    }

    $sourceArtifactFile = "$sourceComponentFolder/artifact.yaml"
    $targetArtifactFile = "$targetComponentFolder/artifact.yaml"

    $sourceVersion = yq eval '.version' "$sourceArtifactFile"
    $sourceArtifact = yq eval '.artifact' "$sourceArtifactFile"
    $sourceArtifactChecksum = yq eval '.artifactChecksum' "$sourceArtifactFile"

    $existingTargetVersion = yq eval '.version' "$targetArtifactFile"
    $existingTargetArtifact = yq eval '.artifact' "$targetArtifactFile"
    $updated = ""

    if ($sourceArtifact -ne $existingTargetArtifact) {
        Write-Host "Existing Artifact: $existingTargetArtifact"
        Write-Host "New Artifact: $sourceArtifact"

        # Update the artifact.yaml file using yq
        yq e -i ".version = `"$($sourceVersion)`"" $targetArtifactFile
        yq e -i ".artifact = `"$($sourceArtifact)`"" $targetArtifactFile
        yq e -i ".artifactChecksum = `"$($sourceArtifactChecksum)`"" $targetArtifactFile

        Write-Host "Database Component Name: $($component.componentName), New Version: $sourceVersion, Target artifact file: $targetArtifactFile"
        $updated = ":green_circle:"
    }
    else {
        Write-Host "Component $($component.componentName) already up-to-date: $sourceVersion"
    }

    $results += [pscustomobject]@{
        component = $componentFolderName
        version = $sourceVersion
        currentVersion = $existingTargetVersion
        updated = $updated
    }
}

# Convert results to compressed JSON
$resultsJson = $results | ConvertTo-Json -Compress -AsArray -Depth 10

# Write the results to a file
return $resultsJson
