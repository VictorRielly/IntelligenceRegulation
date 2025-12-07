# Components

## Description

This folder will contain code for autonomous monitoring of computation. We assume computation to be divisible into fundamental and trustworthy units of computation. Each computation will be deterministic, and each computation will be signed with a hash and an input and output pair. Because each computation unit will be known to all, anyone will be able to verify the computation unit processed the input correctly by independently running the computation unit using their own copy and by comparing the hashes. This can be used equally well for simple as well as very difficult computations (such as feedforwards through very large language models). An application will be a network of fundamental trustworthy computations and with our software any application could be autonomously monitored and corrected and debugged. In principle for instance, with this software we will be able to identify injected malicious inputs or outputs, or hardware errors that result in anomolous behavior. In addition, even in the case where the application behaves in accordance with the fundamental computations, we may still observe abberant or unwanted behavior. In this case, with our technology it will be possible to trace the computations to identify the cause of the aberant behavior and to take actions against it for the future.

We note this would not be the main tool for the global compute network because it requires information about the computations being carried out by the network which may reveal sensitive information. However, we believe this would be an exceptionally valuable tool for companies internally.

## Contents
We provide a python package in which we implement examples of possible fundamental computation units (both simple and complex). We run experiments to demonstrate the effectiveness of our computation monitoring software at identifying abberant behavior in the computations. We also run experiments to determine the computational overhead added by applying this monitor to a computation in a computation network

[Add description of components here]

