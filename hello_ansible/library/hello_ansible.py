#!/usr/bin/python

import socket

def main():
    module = AnsibleModule(
        argument_spec = dict(
            name = dict(required = False, default = "Ansible")
        )
    )

    name = module.params['name']
    hostname = socket.gethostname()

    greeting = "Hello " + name + " from " + hostname
    changed = True

    module.exit_json(
        stdout = greeting
    )

from ansible.module_utils.basic import AnsibleModule
if __name__ == '__main__':
    main()
