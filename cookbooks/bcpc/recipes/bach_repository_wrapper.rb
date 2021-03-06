require 'socket'


# Resolve any DNS address as we may not have working DNS on the cluster nodes (e.g. VM clusters)
uri_parts = URI.split(get_binary_server_url)
chef_server_fqdn = uri_parts[2]
begin
  uri_parts[2] = IPSocket::getaddress(uri_parts[2])
  # VM bootstrap will resolve themselves as localhost
rescue SocketError => e
  # we get the unhelpful error from getaddress, provide some context
  # "getaddrinfo: Name or service not known"
  Chef::Log.error("Got: #{e.message}\nTrying to parse: #{uri_parts[2]}\n")
end

if uri_parts.nil? or uri_parts[2].start_with? '127'
  uri_parts[2] = node['bcpc']['bootstrap']['server']
end

chef_server_ip = nil

# see if we are configured to know about the VIP (e.g. it is in DNS or /etc/hosts)
begin
  chef_server_ip = IPSocket.getaddress(node['bcpc']['bootstrap']['vip'])
rescue SocketError => e
  # we get the unhelpful error from getaddress, provide some context
  # "getaddrinfo: Name or service not known"
  Chef::Log.error("Got: #{e.message}\nTrying to parse: #{node['bcpc']['bootstrap']['vip']}\n")
end

if chef_server_ip.nil? or chef_server_ip.start_with? '127'
  chef_server_ip = node['bcpc']['bootstrap']['server']
end

node.override['bach']['repository']['chef_server_fqdn'] = chef_server_fqdn
node.override['bach']['repository']['chef_server_ip'] = chef_server_ip
node.override['bach']['repository']['chef_url_base'] = URI::HTTP.new(*uri_parts)

# expect a proxy URL
node.override['bach']['repository']['proxy'] = node['bcpc']['bootstrap']['proxy']
node.override['bach']['repository']['gem_server'] = "http://#{node['bcpc']['bootstrap']['vip']}/"

# Setup node.run_state hashes for the Apt repos
node.run_state['bach'] = node.run_state.fetch(['bach'], {})
node.run_state['bach']['repository'] = node.run_state['bach'].fetch('repository', {})
node.run_state['bach']['repository']['gpg_private_key'] = get_config('private_key_base64', 'bootstrap-gpg', 'os')
node.run_state['bach']['repository']['gpg_public_key'] = get_config('bootstrap-gpg-public_key_base64')
