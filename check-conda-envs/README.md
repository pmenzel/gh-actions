# Check conda environment definitions for upgradable packages

This tool is used for parsing [conda environment definitions](https://conda.io/projects/conda/en/latest/user-guide/tasks/manage-environments.html#create-env-file-manually) in `*.y[a]ml` files within the specified folder and searching for packages that can be upgraded.
It can be run as a job in a GitHub Actions workflow. The result of the job is shown in the workflow summary of the GitHub action.
URLs pointing to changelogs of various programs are curated in [map_pkg2changelog.tsv](map_pkg2changelog.tsv) and are used in the output tables.

It also enforces the use of exact version numbers in package definitions, for example:
```
  - bioconda::snakemake=6.15.5   # allowed
  - bioconda::snakemake==6.15.5  # allowed
  - bioconda::snakemake>=6.15.5  # NOT allowed
```
Invalid definition lines will cause the job/workflow to fail.

Sections for pip packages (after the line `- pip:`) are ignored.

## Example output of the workflow summary

A table is produced for each conda environment file in the workflow summary section, showing the status of each package.

For example, from [ont-assembly-snake](https://github.com/pmenzel/ont-assembly-snake):

![Example Output](example-output.png?raw=true)

## Usage

### Standalone

For example, check all conda environment files located in the `env/`-folder:
```
./check-conda-envs/check-all-conda-envs.sh /path/to/env/

```

⚠️  The program requires a working conda installation to run, as it will use the `conda search` command.

### Github Action

Either add the file [check-conda-envs.yml](check-conda-envs.yml) to the target repository's `.github/workflows/` folder
and modify the environment variable `TARGET` therein

**or**

add this job to an already existing workflow:
```
  check-conda-upgrades:
    runs-on: "ubuntu-latest"

    # this defines the repository folder in which the conda environment files (*.y[a]ml) are located
    # multiple folders can be set with: TARGET: "env1 subfolder/env2"
    env:
      TARGET: "env"

    steps:
      # checkout this repository
      - uses: actions/checkout@v3

      # checkout pmenzel/gh-actions
      - uses: actions/checkout@v3
        with:
          repository: pmenzel/gh-actions
          ref: master
          path: ./external/gh-actions

      # https://github.com/marketplace/actions/setup-miniconda
      - uses: conda-incubator/setup-miniconda@v2
        with:
          channels: conda-forge,bioconda
      - run: |
          conda info

      - name: Run gh-actions/check-conda-envs/check-all-conda-envs.sh
        run: ./external/gh-actions/check-conda-envs/check-all-conda-envs.sh ${{env.TARGET}}

```
and modify the environment variable `TARGET` accordingly.


