require 'spec_helper'
require 'deep_merge'

describe 'duplicacy' do
  let(:facts) do
    {
      "os" => {
        "architecture" => "amd64",
        "family" => "Gentoo",
        "hardware" => "x86_64",
        "name" => "Gentoo",
        "release" => {
          "full" =>  "2.4.1",
          "major" => "2",
          "minor" => "4"
        },
      }
    }
  end

  context 'Compiles' do
    it { is_expected.to compile }

    it { is_expected.to contain_package('app-backup/duplicacy-bin') }
    it { is_expected.to contain_package('mail-client/mutt') }
  end
end
