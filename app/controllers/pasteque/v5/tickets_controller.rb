class Pasteque::V5::TicketsController < Pasteque::V5::BaseController
  manage_restfully only: [:index, :show]
end