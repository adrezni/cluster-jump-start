# Quckstart for RHOAI

This is an example of how to setup OpenShift AI

## Quickstart

Run default demo

```sh
until oc apply -k demos/default; do : ; done
```

Run Structured Data for Healthcare Workshop

```sh
until oc apply -k workshops/structured-data-healthcare; do : ; done

. workshops/workshop_functions.sh
workshop_create_users workshops/structured-data-healthcare/user0 40
```

Run Parasol Insurance Demo (simplified) - Not Working

```sh
until oc apply -k demos/parasol-insurance/00-prereqs; do : ; done
until oc apply -k demos/parasol-insurance; do : ; done
```

## Uninstall

```sh
oc apply -k demo/uninstall
```
