Vagrant.configure("2") do |config|
  config.vm.box = "generic/ubuntu2004"
  
  # Bastion Host
  config.vm.define "bastion" do |bastion|
    bastion.vm.hostname = "bastion"
    bastion.vm.network "private_network", ip: "192.168.56.10"
    bastion.vm.network "forwarded_port", guest: 8080, host: 8080
    bastion.vm.network "forwarded_port", guest: 5002, host: 5002
    
    bastion.vm.provider :virtualbox do |vb|
      vb.memory = 1024
      vb.cpus = 1
    end
    bastion.vm.provision "file", source: "./services", destination: "/home/vagrant/services"
    bastion.vm.provision "file", source: "./scripts/run_api_test.sh", destination: "/home/vagrant/scripts/run_api_test.sh"
    bastion.vm.provision "shell", path: "./scripts/provision-bastion.sh"
  end

  # App Server 1
  config.vm.define "app1" do |app|
    app.vm.hostname = "app1"
    app.vm.network "private_network", ip: "192.168.56.11"
    app.vm.network "forwarded_port", guest: 5000, host: 5000
    
    app.vm.provider :virtualbox do |vb|
      vb.memory = 1024
      vb.cpus = 1
    end
    app.vm.provision "file", source: "./services/account-service", destination: "/home/vagrant/account-service"
    app.vm.provision "shell", path: "./scripts/provision-app1.sh"
  end

  # App Server 2
  config.vm.define "app2" do |app|
    app.vm.hostname = "app2"
    app.vm.network "private_network", ip: "192.168.56.12"
    app.vm.network "forwarded_port", guest: 5001, host: 5001
    
    app.vm.provider :virtualbox do |vb|
      vb.memory = 1024
      vb.cpus = 1
    end
    app.vm.provision "file", source: "./services/transaction-service", destination: "/home/vagrant/transaction-service"
    app.vm.provision "shell", path: "./scripts/provision-app2.sh"
  end

  # Database Server
  config.vm.define "db" do |db|
    db.vm.hostname = "db"
    db.vm.network "private_network", ip: "192.168.56.20"
    
    db.vm.provider :virtualbox do |vb|
      vb.memory = 1024
      vb.cpus = 1
    end
    db.vm.provision "shell", path: "./scripts/setup-database.sh"
  end

  # Base provisioning
  config.vm.provision "shell", inline: <<-SHELL
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y curl wget vim net-tools jq ufw
    echo "192.168.56.10 bastion" >> /etc/hosts
    echo "192.168.56.11 app1" >> /etc/hosts
    echo "192.168.56.12 app2" >> /etc/hosts
    echo "192.168.56.20 db" >> /etc/hosts
  SHELL

  # Security Hardening
  config.vm.provision "shell", path: "./scripts/vm-security.sh"
end