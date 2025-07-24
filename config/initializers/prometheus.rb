require 'prometheus/client'
require_relative '../app/models/services/instrumentor'

Services::Instrumentor.initialize_metrics
