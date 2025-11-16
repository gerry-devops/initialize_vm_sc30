# ActiveMQ deployment configuration

Files:

- amq-configmap.yaml
- amq-deployment.yaml
- amq-secret.yaml
- amq-service.yaml

*Before* ActiveMQ deployment starts:

## amq-configmap.yaml

`hostname` value should be changed to the address of httpd in front of Polaris.

## amq-sercret.yaml:

`hydra.user.password` should be changed to the password for the `hydra` user that you set.

The password for the Hydra user could be changed as follows:

```curl -v -X PUT -G -u polaris@mobileiron.com:polaris123 'https://<address_of_httpd_in_front_of_polaris>/api/v1/account/<hydra_account_id>/password' --data-urlencode 'password=Mi4man112233#'```

> where default value for the `hydra_account_id` is `10002`.

`producer.password` password should match to the value you defined for `activemq.password` variable [in the polaris-secret.yaml file](../polaris/polaris-secret.yaml)

By default, ActiveMQ deployment is shipped with self-signed certificates, therefore, it is recommended to replace them by replacing the values of `server-cert.pem` and `server-key.pem` with your own.
