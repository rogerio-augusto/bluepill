require 'socket'

module Bluepill
  module Socket
    RETRIES = 5
    @@current_retry = 0

    extend self

    def client(base_dir, name, &b)
      UNIXSocket.open(socket_path(base_dir, name), &b)
    end

    def client_command(base_dir, name, command, timeout)
      client(base_dir, name) do |socket|
        Timeout.timeout(timeout) do
          socket.puts command
          Marshal.load(socket)
        end
      end
    rescue EOFError, Timeout::Error
      @@current_retry += 1
      puts "Retry #{@@current_retry} of #{RETRIES}"
      if @@current_retry <= RETRIES
        client_command(base_dir, name, command, timeout)
      else
        abort("Socket Timeout: Server may not be responding")
      end
    ensure
      @@current_retry = 0
    end

    def server(base_dir, name)
      socket_path = self.socket_path(base_dir, name)
      begin
        UNIXServer.open(socket_path)
      rescue Errno::EADDRINUSE
        # if sock file has been created.  test to see if there is a server
        begin
          UNIXSocket.open(socket_path)
        rescue Errno::ECONNREFUSED
          File.delete(socket_path)
          return UNIXServer.open(socket_path)
        else
          logger.err("Server is already running!")
          exit(7)
        end
      end
    end

    def socket_path(base_dir, name)
      File.join(base_dir, 'socks', name + ".sock")
    end
  end
end