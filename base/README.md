# Example Architecture - Scale Out

This [Kustomize][Kustomize] "application" contains the base K8s resources that comprise the Scale-Out architecture.

`kustomization.yml` - This Kustomize YAML definition is the primary aggregator of the various resources for the solution.

## Primary Resources

`backend-service.yml` - This set of [Service][Service] definitions define _headless services_ for the Backend Gateways.  Note on the second and third definitions, the `selector` for targeting the `-0` (Redundancy Primary) and `-1` (Redundancy Backup) replicas of the StatefulSet.  These services are what are used by the Frontend gateways to target for GAN connections against the redundant pair.

`backend-statefulset.yml` - The Backend [StatefulSet][StatefulSet] defines the specification for a redundant pair of backend Ignition Gateway's.

`frontend-ingress.yml` - The base [Ingress][Ingress] resource for the Frontend gateways is then augmented in the [`aws-eks`](../aws-eks) overlay with annotations for driving the creation of an AWS Load Balancer. 

`frontend-service.yml` - The Frontend [Service][Service] targets the Frontend gateways from the respective StatefulSet and is referenced by the Ingress resource.

`frontend-statefulset.yml` - The Frontend [StatefulSet][StatefulSet] defines the specification for the scale-out replicated Frontend pairs.  NOTE: replication of the _Pods_ themselves doesn't drive any automatic replication of application contents.  This would still have to be conducted through another method, such as our Enterprise Administration Module from the Backend EAM Controller.

`gan-certificates.yml` - The resources in this file define the GAN Certificate Authority (from which the public CA Certificate is trusted by the Backend/Frontend Gateways) and the Backend/Frontend GAN Client Keystores (used for encrypted GAN connectivity).

## Other Files

`config` - This contains configuration "files" that are used in the [initContainers][initContainers] for the Frontend/Backend Gateways.  They're gathered into [ConfigMaps][ConfigMaps] via the [configMapGenerator][configMapGenerator] configuration in the Kustomize solution.

`scripts` - These helper scripts are leveraged by the [initContainers] as well but are separated from our configuration files (that don't need executable privileges).  They're also gathered via the [configMapGenerator][configMapGenerator].

`secrets` - The `base.env` environment variable file here is gathered and translated to K8s [Secrets][Secrets] by [secretGenerator][secretGenerator].

## Self-Signed ClusterIssuer

The `selfsigned-issuer.yml` here in the parent folder is a cluster-wide "ClusterIssuer" that is intended to help bootstrap a custom root certificate for our Gateway Network Certificate Authority (CA).  It only needs to be applied once at the cluster level.

[Service]: https://kubernetes.io/docs/concepts/services-networking/service/
[StatefulSet]: https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/
[Ingress]: https://kubernetes.io/docs/concepts/services-networking/ingress/
[ConfigMaps]: https://kubernetes.io/docs/concepts/configuration/configmap/
[Secrets]: https://kubernetes.io/docs/concepts/configuration/secret/
[initContainers]: https://kubernetes.io/docs/concepts/workloads/pods/init-containers/
[Kustomize]: https://kubectl.docs.kubernetes.io/guides/introduction/kustomize/
[configMapGenerator]: https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/configmapgenerator/
[secretGenerator]: https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/secretgenerator/
