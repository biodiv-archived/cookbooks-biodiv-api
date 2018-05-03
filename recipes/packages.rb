if platform_family?('debian')
  e = apt_update 'update' do
    action :nothing
  end
  e.run_action(:update)
end

# install https transport for apt
package 'apt-transport-https' do
  only_if { apt_installed? }
end

# install apt utility packages
package "imagemagick" do
  only_if { apt_installed? }
end

package "gdal-bin" do
  only_if { apt_installed? }
end

package "libgeoip1" do
  only_if { apt_installed? }
end

package "libgtk2.0-0" do
  only_if { apt_installed? }
end

package "libproj-dev" do
  only_if { apt_installed? }
end

package "binutils" do
  only_if { apt_installed? }
end

package "jpegoptim" do
  only_if { apt_installed? }
end

package "ntp" do
  only_if { apt_installed? }
end

package "mailutils" do
  only_if { apt_installed? }
end
