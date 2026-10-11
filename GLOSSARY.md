# SBC host lifecycle

Vocabulary for describing the support and recovery state of the single-board computer hosts.

## Language

**Evaluation-checked host**: A host whose configuration passes the repository's evaluation checks.
This status does not imply a completed system build or a working device. _Avoid_: Supported host,
verified host

**Build-checked host**: A host whose complete system artifacts have been built successfully. Its
physical boot and required hardware behavior may remain unverified. _Avoid_: Working host,
boot-verified host

**Hardware-verified host**: A host that has passed the agreed checks on its physical board,
including startup and required services. This status applies to the tested combination of hardware
and software. _Avoid_: CI-verified hardware, build-verified hardware

**USB unlock key**: Unlock material stored in a designated raw region of a USB partition. It is
separate from a recovery passphrase and is not an ordinary file copied into the partition's
filesystem. _Avoid_: USB keyfile, mounted key file

**Fresh installation**: Provisioning a host without depending on a previous installed system or its
boot generations. Recovery requirements concern the new installation rather than compatibility with
an old vendor installation. _Avoid_: Vendor migration, old-generation rollback

**Unverified host**: A host that lacks the required physical validation for its intended use.
Evaluation and build evidence should be stated separately rather than inferred from this label.
_Avoid_: Broken host, unsupported hardware
