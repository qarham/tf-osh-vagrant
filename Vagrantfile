VAGRANTFILE_API_VERSION = "2"

# Require YAML module
require 'yaml'

# Read YAML file with box details
servers = YAML.load_file('servers.yaml')

# Create boxes
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.provision "ansible" do |ansible|
    ansible.playbook = "config.yaml"
    ansible.verbose = true
  end

if Vagrant.has_plugin?("vagrant-timezone")
     config.timezone.value="America/New_York"
  end

  # Iterate through entries in YAML file
  servers.each do |servers|
    config.vm.define servers["name"] do |srv|
      srv.vm.box = servers["box"]
      srv.vm.network "public_network", bridge: "br0", ip: servers["ip-mgmt"]
      srv.vm.network "public_network", bridge: "br1", ip: servers["ip-control-data"]
      srv.vm.provision "shell",inline: "route add default gw 10.13.82.1"
      srv.vm.provision "shell",inline: "eval `route -n | awk '{ if ($8 ==\"enp0s3\" && $2 != \"0.0.0.0\") print \"route del default gw \" $2; }'`"
      srv.vm.provision "shell", path: "scripts/hosts.sh"
      srv.vm.provision "shell", path: "scripts/install_3rd_pack.sh"
      srv.vm.provision "shell", path: "scripts/resolve-conf.sh"
      srv.vm.provision "shell", path: "scripts/ntp.sh" 
      srv.vm.provision "shell", path: "scripts/enable_root_login.sh"
      srv.vm.hostname = servers ["name"]
#      srv.hostmanager.enabled = true
#      srv.hostmanager.manage_host = true
      srv.vm.provider :virtualbox do |vb|
        vb.name = servers["name"]
        vb.memory = servers["ram"]
        if servers.has_key?("cpus")
          vb.cpus = servers["cpus"]
          vb.customize ["setextradata", :id, "VBoxInternal/CPUM/SSE4.1", "1"]
          vb.customize ["setextradata", :id, "VBoxInternal/CPUM/SSE4.2", "1"]
          vb.customize ["modifyvm", :id, "--paravirtprovider", "kvm"]
          end
        end
      end
  end
    config.vm.define "k8s-node01" do |web|
      web.vm.provision "OSH-Install", run: "never", type:  "shell", 
        path: "scripts/provision-osh-helm.sh"
    end
    config.vm.define "k8s-node01" do |web|
      web.vm.provision "TF-Install", run: "never", type:  "shell", 
        path: "scripts/provision-tf-parent-chart-helm.sh"
    end
    config.vm.define "k8s-node01" do |web|
      web.vm.provision "Test-VN-VM", run: "never", type:  "shell", 
        path: "scripts/basic-sanity-test.sh"
    end
    config.vm.define "k8s-node01" do |web|
      web.vm.provision "TP-Delete", run: "never", type:  "shell", 
        path: "scripts/delete-tp.sh"
    end
end
