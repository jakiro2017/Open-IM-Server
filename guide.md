#How to debug module

- Choose module want to debug
Example: `open_im_api`
edit `debug.sh` and fill `reload=open_im_api`

- Build docker
`sudo docker-compose build -f docker-compose_dev.yaml`
- Connect to docker and run `debug.sh`
`sudo docker-compose -f docker-compose_dev.yaml exec open_im_server zsh`
`cd /src`
`zsh -x./debug.sh`
- Using vscode and connect to localhost port 2345
- Happy hunting!