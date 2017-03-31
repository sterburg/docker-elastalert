Docker container that runs elastalert.
You can find more details about [elastalert here](https://github.com/Yelp/elastalert)

## Usage ##
```
 oc project logging
 oc new-app --name=elastalert https://github.com/sterburg/docker-elastalert
 oc -n logging describe secret logging-elasticsearch
 oc -n volume -add dc/elastalert --type=secret --secret-name=logging-elasticsearch --mount-path=/var/run/secrets/admin
```
