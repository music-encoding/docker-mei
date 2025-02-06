# docker-mei

Docker image for anything concerning the MEI build process.

The image contains all the necessary dependencies:

* **Apache ANT:** to execute all necessary build steps
* **Saxon HE:** for executing XSL-Transformations
* **Verovio Toolkit:** to render MEI examples to SVG
* **Prince XML:** to convert the Guidelines HTML to PDF

The image is being published on the GitHub Container Registry (ghcr.io).

## Example usage

The following examples use different Docker commands. Detailed explanations of these Docker commands can be found in the [Docker Command-line reference](https://docs.docker.com/engine/reference/run/) but here’s a concise explanation:

| Command Particle | Description |
|------------------|-------------|
| [Running a container] | |
| `docker run` | Runs a docker process as an isolated container. Must specify an image to derive the container from. |
| `--rm` | Automatically clean up the Docker container and remove the file system when the container exits. |
| `-it` | Open an interactive shell. |
| `-v` (or `--volume`) | mount a folder from the host as a volume in the Docker container, here the current working directory (`pwd`) gets mounted into `/opt/docker-mei/music-encoding` in the docker container |
| `--name` | (optional) Identify the container with a local name. If not given, Docker generates a random string name. |
| `ghcr.io/music-encoding/docker-mei:latest` or `docker-mei:local` | The Docker image (latest version) to be used and pulled, wether from a remote registry like ghcr.io or a local build process. |
| `ant -noinput -buildfile music-encoding/build.xml` | Execute ant with the build.xml file of the music-encoding repo. |
| `-Ddocker=true` | A flag to indicate that ant is triggered via Docker. |
| [Building an image] | |
| `docker buildx build` | Builds a Docker image from a Dockerfile. If not specified, the file is assumed to be in the current working directory. |
| `-t` | Allows to specify some name and optional tag for the Docker image to be built, e.g., `docker-mei:local` |


### Pulling the Docker image

```bash
docker pull ghcr.io/music-encoding/docker-mei:latest
```

Although the image will be automatically pulled when you run a docker container via `docker run`, the image will not be automatically updated to the latest version on subsequent runs. So it is recommended to run the `docker pull` command above from time to time.

### Running without an interactive shell
You can run the Docker container without an interactive shell and submit the command to execute directly when calling the container. For example, you could submit the command to build all MEI assets, i.e., compiled ODD files for the customization, RNG schemata for the customizations, HTML and PDF of the MEI Guidelines:

```bash
docker run --rm -v /ABSOLUTE/PATH/TO/YOUR/MUSIC_ENCODING/CLONE:/opt/docker-mei/music-encoding --name docker-mei ghcr.io/music-encoding/docker-mei:latest ant -noinput -buildfile music-encoding/build.xml -Ddocker=true
```

For example, if you start the Docker image from the root folder of your music-encoding repository clone:

```bash
docker run --rm -v `pwd`:/opt/docker-mei/music-encoding --name docker-mei ghcr.io/music-encoding/docker-mei:latest ant -noinput -buildfile music-encoding/build.xml -Ddocker=true
```

### Running with an interactive shell

If you need more fine-grained access and control, you can run the Docker container in an interactive shell by adding an `-it` flag.

```bash
docker run --rm -it -v /ABSOLUTE/PATH/TO/YOUR/MUSIC_ENCODING/CLONE:/opt/docker-mei/music-encoding --name docker-mei ghcr.io/music-encoding/docker-mei:latest
```

For example, if you start the Docker image from the root folder of your music-encoding repository clone:

```bash
docker run --rm -it -v `pwd`:/opt/docker-mei/music-encoding --name docker-mei ghcr.io/music-encoding/docker-mei:latest
```

This will open a shell prompt at the root folder of the container (`/opt/docker-mei`). In order to proceed with building mei assets, you will need to navigate to the subfolder `music-encoding`.

```bash
cd music-encoding
```

From here you can enter the corresponding commands, as found in the [build.xml](https://github.com/music-encoding/music-encoding/blob/develop/build.xml) file of the [music-encoding repository](https://github.com/music-encoding/music-encoding), on the command line. For an overview of all available build commands see [BUILD_COMMANDLINE.md](https://github.com/music-encoding/music-encoding/blob/develop/BUILD_COMMANDLINE.md#available-targets).

For example:

```bash
root@0f60c61b20d4:/opt/docker-mei/music-encoding# ant build-compiled-odd
```

> [!IMPORTANT] 
> Please note that for some commands it is necessary to add a `-Ddocker=true` flag to be run from an interactive shell. Therefore it is recommended to use that flag in any case, when running build commands on an interactive Docker shell:

For example:

```bash
root@0f60c61b20d4:/opt/docker-mei/music-encoding# ant generate-images -Ddocker=true
```

## Local build and usage

Clone the repository to your machine, e.g., via the command line:

1. Navigate to the parent directory where you want your clone to live, e.g.:

    ```bash
    cd /temp/
    ```

2. Clone the repository:

    ```bash
    git clone https://github.com/music-encoding/docker-mei.git
    ```

3. Navigate to the new repository clone’s root directory:

    ```bash
    cd docker-mei
    ```

4. Build the Docker image locally:

    ```bash
    docker buildx build -t [some-name-tag] .
    ```

    N.B.: Before executing the above command, replace _[some-name-tag]_ with a name of your liking, e.g.:

    ```bash
    docker buildx build -t docker-mei:local .
    ```

5. Run your local Docker image

    ```bash
    docker run --rm -v [/ABSOLUTE/PATH/TO/YOUR/MUSIC_ENCODING/CLONE]:/opt/docker-mei/music-encoding --name docker-mei [some-name-tag]
    ```

    N.B.: Before executing the above command, replace the _[SQUARE-BRACKETS]_ with your local variables. For example, if you start your local Docker image from the root folder of your music-encoding repository clone:
    ```bash
    docker run --rm -v `pwd`:/opt/docker-mei/music-encoding --name docker-mei docker-mei:local
    ```
