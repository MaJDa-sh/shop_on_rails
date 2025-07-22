if @actions
  json.array! @actions do |action|
    json.extract! action, :id, :action_type, :created_at
  end
else
  json.errors @errors
end
json.status @status
