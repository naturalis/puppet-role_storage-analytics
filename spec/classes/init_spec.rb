require 'spec_helper'
describe 'role_cron' do

  context 'with defaults for all parameters' do
    it { should contain_class('role_cron') }
  end
end
