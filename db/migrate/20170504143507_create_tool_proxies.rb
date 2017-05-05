class CreateToolProxies < ActiveRecord::Migration[5.0]
  def change
    create_table :tool_proxies do |t|
      t.string :tcp_url
      t.string :base_url
    end
  end
end
