import logging
import os
import re
from pathlib import Path

LOG = logging.getLogger(__name__)


def get_version_from_pyproject():
    """Extract the version from pyproject.toml file."""
    try:
        # Get the project root directory (utils.py is in the root)
        project_root = Path(__file__).parent
        pyproject_path = project_root / "pyproject.toml"

        # Check if the file exists
        if not pyproject_path.exists():
            LOG.warning(f"pyproject.toml not found at {pyproject_path}")
            return os.environ.get("OBSERVABILITY_TEST_APP_VERSION", "unknown")

        # Read the pyproject.toml file and look for version in [project] section
        with open(pyproject_path, "r") as f:
            content = f.read()

        # Look for version in [project] section
        project_section_match = re.search(
            r"\[project\](.*?)(?=\n\[|\Z)", content, re.DOTALL
        )
        if project_section_match:
            project_section = project_section_match.group(1)
            version_match = re.search(r'version\s*=\s*"([^"]+)"', project_section)
            if version_match:
                return version_match.group(1)

        LOG.warning("Version not found in [project] section of pyproject.toml")
        return os.environ.get("OBSERVABILITY_TEST_APP_VERSION", "unknown")

    except Exception as e:
        LOG.error(f"Error reading version from pyproject.toml: {e}")
        return os.environ.get("OBSERVABILITY_TEST_APP_VERSION", "unknown")
