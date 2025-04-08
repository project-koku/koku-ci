import json
import re
import urllib.request
from pathlib import Path

# Filepath to your YAML file
file_path = Path("pipelines/pipeline-build.yaml")

# Base URL for the container registry API (Quay.io in this case)
registry_api_url = "https://quay.io/api/v1/repository"

# Regular expression to match the task bundle lines
sha_pattern = re.compile(
    r"value: quay\.io/konflux-ci/tekton-catalog/(.*?):(.*?)@sha256:[a-f0-9]+"
)


# Function to fetch the sha256 digest for a specific tag of a task
def fetch_sha_for_tag(task_name, tag):
    try:
        # Construct the API URL for the task and tag
        url = f"{registry_api_url}/konflux-ci/tekton-catalog/{task_name}/tag/?specificTag={tag}"
        with urllib.request.urlopen(url) as response:
            data = json.loads(response.read().decode())
            tags = data.get("tags", [])

            # Find the tag without the "expiration" key
            for tag_info in tags:
                if "expiration" not in tag_info and "manifest_digest" in tag_info:
                    return tag_info["manifest_digest"]
    except Exception as e:
        print(f"Error fetching SHA for {task_name}:{tag}: {e}")
    return None


# Read the file and extract tasks and tags
with file_path.open("r") as file:
    content = file.read()

# Extract task names and tags from the file
tasks_with_tags = {
    (match.group(1), match.group(2)) for match in sha_pattern.finditer(content)
}

# Fetch the sha256 values for all tasks and tags
latest_shas = {}
for task_name, tag in tasks_with_tags:
    if latest_sha := fetch_sha_for_tag(task_name, tag):
        latest_shas[(task_name, tag)] = latest_sha
    else:
        print(f"Warning: Could not fetch SHA for {task_name}:{tag}")


# Replace old sha256 values with the latest ones
def replace_sha(match):
    task_name = match.group(1)
    tag = match.group(2)
    task_line = match.group(0).split("@sha256:")[0]
    new_sha = latest_shas.get((task_name, tag))
    return f"{task_line}@{new_sha}" if new_sha else match.group(0)


updated_content = sha_pattern.sub(replace_sha, content)

# Write the updated content back to the file
with file_path.open("w") as file:
    file.write(updated_content)

print("SHA256 values updated successfully!")
