require 'aws-sdk-ec2'
require 'aws-sdk-configservice'
require 'csv'

class DescribeSgRelationships
  attr_reader :results, :ec2_client, :cfg_client

  def initialize(region, akid, secret)
    @results = []
    @ec2_client = Aws::EC2::Client.new(region: region, credentials: Aws::Credentials.new(akid, secret))
    @cfg_client = Aws::ConfigService::Client.new(region: region, credentials: Aws::Credentials.new(akid, secret))
  end

  def describe_security_groups(params={})
    @ec2_client.describe_security_groups(params)
  end
  def get_resource_config_history(params={})
    @cfg_client.get_resource_config_history(params)
  end

  def generate_results
    return @results unless @results.empty?
    
    describe_security_groups.security_groups.each do |sg|
      get_resource_config_history(resource_type: 'AWS::EC2::SecurityGroup', resource_id: sg.group_id).configuration_items.each do |item|
        if item.relationships.empty?
          result = Result.new(
            group_id: sg.group_id, group_name: sg.group_name, description: sg.description,
            configuration_item_capture_time: item.configuration_item_capture_time, configuration_item_status: item.configuration_item_status,
          )
          @results << result
          next
          
        else
          item.relationships.each do |rel|
            result = Result.new(
              group_id: sg.group_id, group_name: sg.group_name, description: sg.description,
              configuration_item_capture_time: item.configuration_item_capture_time, configuration_item_status: item.configuration_item_status,
              resource_type: rel.resource_type, resource_id: rel.resource_id, relationship_name: rel.relationship_name
            )

            @results << result
          end
        end
      end
    end

    @results
  end

  def to_csv(path=nil)
    generate_results if @results.empty?
    csv = CSV.generate(headers: Result.members, write_headers: true) do |row|
      @results.each do |result|
        row << result.to_h
      end
    end

    if path
      open(path, 'w') do |io|
        io.write csv
      end
    end

    csv
  end

  class Result < Struct.new(
    :group_id, :group_name, :description,
    :configuration_item_capture_time, :configuration_item_status,
    :resource_type, :resource_id, :relationship_name,
    keyword_init: true)
  end
end