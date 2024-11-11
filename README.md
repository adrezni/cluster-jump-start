# Quckstart for RHOAI

This is an example of how to setup OpenShift AI

## Quickstart

Run Demo

```sh
until oc apply -k demo; do : ; done
```

Run Structured Data for Healthcare Workshop

```sh
until oc apply -k workshops/structured-data-healthcare; do : ; done

. workshops/workshop_functions.sh
workshop_create_users workshops/structured-data-healthcare/user0 40
```

## Uninstall

```sh
oc apply -k demo/uninstall
```
