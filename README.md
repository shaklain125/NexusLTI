# NexusLTI

## Docker commands

CLEAN DOCKER

```
docker system prune -a
```

PULL Rails **(It is required. Add to Docker if it's not added already)**

```
docker pull docker.io/library/rails:4.2.4
```

## Set up

1. Clone the repo in a new folder

```
git clone --single-branch --branch master https://github.com/shaklain125/NexusLTI.git . && cd nexus_monorepo
```

2. Set Env (manually create the env variables by following the Nexus repo instructions the first time and save it to a file for future use)

```
sudo make init-env && cat /mnt/d/Desktop/Project/ENV_SETTINGS.txt > .env.list
```

3. Install configPage node_modules **(required)**

```
cd ./sample-configurable-tool/configPage && npm i && cd ../../
```

4. Install web-ide dependencies **(required)**

```
cd ./nexus/lib/web-ide && npm i && cd ../../../
```

### Nexus commands

`sudo make abstract-rsa` AND COPY RSA TO GITHUB SSH KEY https://github.com/settings/keys

`sudo make build`

`sudo make init-nexus`

`sudo make run`

## Development

1. Open VScode `code .` in Linux environment (e.g. WSL2).
2. Open two terminals, one for pushing to GitHub in the **root** folder, and the other to use it **nexus_monorepo** folder.

### Git Commands

`git add . && git commit -s -m "message"`

`git push https://github.com/shaklain125/NexusLTI.git master`
