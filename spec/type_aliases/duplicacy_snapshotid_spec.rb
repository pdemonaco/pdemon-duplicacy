require 'spec_helper'

describe 'Duplicacy::SnapshotID' do
  it {
    is_expected.to allow_value('my-repo', 'xen_files', 'etc_factorio01')
  }

  it {
    is_expected.not_to allow_value('my repo', 'etc/factorio01', '', 'etc_factorio01.demona.co')
  }
end
