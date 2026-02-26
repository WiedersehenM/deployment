```bash
terraform output -raw orion_vm_private_key_pem > orion.pem

chmod 600 orion.pem

ssh -i orion.pem orion@$(terraform output -raw orion_vm_public_ip)

ssh -i orion.pem orion@$(terraform output -raw orion_docker_vm_public_ip)

```