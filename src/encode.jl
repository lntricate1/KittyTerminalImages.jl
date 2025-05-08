using ImageCore: Colorant, Color, TransparentColor, AbstractRGB, AbstractRGBA
using ImageCore: RGB, RGBA, N0f8
using ImageCore: red, green, blue, alpha
import Base64
using Base64: Base64EncodePipe
using CodecZlib: ZlibCompressorStream

# public kitty_encode, kitty_encode_chunked, kitty_encode_compressed, kitty_encode_chunked_compressed

# Non transparent colors
"""
    kitty_encode(io, image; control_data)

Write the `image` to `io` using the kitty protocol, unchunked and uncompressed.

Possible control_data options (see https://sw.kovidgoyal.net/kitty/graphics-protocol.html#control-data-reference)
- `a="t"`
- `q="0"`
- `i="0"`, `I="0"`, `p="0"`
- `x="0"`, `y="0"`, `w="0"`, `h="0"`
- `X="0"`, `Y="0"`, `c="0"`, `r="0"`
- `C="0"`
- `z="0"`
- `P="0"`, `Q="0"`
- `H="0"`, `V="0"`
"""
function kitty_encode(io::IO, img::Array{Color}; controll_data...)
  kitty_encode(io, RGB{N0f8}.(img); controll_data...)
end

function kitty_encode(io::IO, img::Array{<:AbstractRGB{N0f8}}; controll_data...)
  height, width = string.(size(img))
  payload = permutedims(img)
  write_kitty_image_escape_sequence(io, payload; f="24", s=width, v=height, controll_data...)
end

"""
    kitty_encode_chunked(io, image; control_data)

Write the `image` to `io` using the kitty protocol, chunked and uncompressed.

Possible control_data options (see https://sw.kovidgoyal.net/kitty/graphics-protocol.html#control-data-reference)
- `a="t"`
- `q="0"`
- `i="0"`, `I="0"`, `p="0"`
- `x="0"`, `y="0"`, `w="0"`, `h="0"`
- `X="0"`, `Y="0"`, `c="0"`, `r="0"`
- `C="0"`
- `z="0"`
- `P="0"`, `Q="0"`
- `H="0"`, `V="0"`
"""
function kitty_encode_chunked(io::IO, img::Array{Color}; controll_data...)
  kitty_encode_chunked(io, RGB{N0f8}.(img); controll_data...)
end

function kitty_encode_chunked(io::IO, img::Array{<:AbstractRGB{N0f8}}; controll_data...)
  height, width = string.(size(img))
  payload = permutedims(img)
  buffer = Vector{UInt8}(undef, 4min(length(img), 1024))
  for index in 1:1024:length(img)
    m = index + 1023 < length(img) ? "1" : "0"
    if index == 1
      write_kitty_image_escape_sequence(io, payload, index, buffer; f="24", s=width, v=height, m=m, controll_data...)
    else
      write_kitty_image_escape_sequence(io, payload, index, buffer; m=m)
    end
  end
end

"""
    kitty_encode_compressed(io, image; control_data)

Write the `image` to `io` using the kitty protocol, unchunked and compressed.

Possible control_data options (see https://sw.kovidgoyal.net/kitty/graphics-protocol.html#control-data-reference)
- `a="t"`
- `q="0"`
- `i="0"`, `I="0"`, `p="0"`
- `x="0"`, `y="0"`, `w="0"`, `h="0"`
- `X="0"`, `Y="0"`, `c="0"`, `r="0"`
- `C="0"`
- `z="0"`
- `P="0"`, `Q="0"`
- `H="0"`, `V="0"`
"""
function kitty_encode_compressed(io::IO, img::Array{Color}; controll_data...)
  kitty_encode_compressed(io, RGB{N0f8}.(img); controll_data...)
end

function kitty_encode_compressed(io::IO, img::Array{<:AbstractRGB{N0f8}}; controll_data...)
  height, width = string.(size(img))
  payload = permutedims(img)
  write_kitty_image_escape_sequence_compressed(io, payload; f="24", s=width, v=height, o="z", controll_data...)
end

"""
    kitty_encode_chunked_compressed(io, image; control_data)

Write the `image` to `io` using the kitty protocol, chunked and compressed.

Possible control_data options (see https://sw.kovidgoyal.net/kitty/graphics-protocol.html#control-data-reference)
- `a="t"`
- `q="0"`
- `i="0"`, `I="0"`, `p="0"`
- `x="0"`, `y="0"`, `w="0"`, `h="0"`
- `X="0"`, `Y="0"`, `c="0"`, `r="0"`
- `C="0"`
- `z="0"`
- `P="0"`, `Q="0"`
- `H="0"`, `V="0"`
"""
function kitty_encode_chunked_compressed(io::IO, img::Array{Color}; controll_data...)
  kitty_encode_chunked_compressed(io, RGB{N0f8}.(img); controll_data...)
end

function kitty_encode_chunked_compressed(io::IO, img::Array{RGB{N0f8}}; controll_data...)
  height, width = string.(size(img))
  payload = permutedims(img)

  # TODO: find a better way of doing this (if there is one)
  # also check if using red, green, blue is faster than converting to RGB
  io1 = IOBuffer()
  buffer = Base64EncodePipe(io1)
  stream = ZlibCompressorStream(buffer)
  write(stream, payload)
  close(stream)
  close(buffer)

  partitions = Iterators.partition(take!(io1), 4096)
  for (i, chunk) in enumerate(partitions)
    m = i < length(partitions) ? "1" : "0"
    if i == 1
      write_kitty_image_escape_sequence_raw(io, chunk; f="24", s=width, v=height, m=m, o="z", controll_data...)
    else
      write_kitty_image_escape_sequence_raw(io, chunk; m=m)
    end
  end
end





# Transparent colors

function kitty_encode_chunked(io::IO, img::Array{TransparentColor}; controll_data...)
  kitty_encode_chunked(io, RGBA{N0f8}.(img); controll_data...)
end

function kitty_encode_chunked(io::IO, img::Array{RGBA{N0f8}}; controll_data...)
  height, width = string.(size(img))
  payload = permutedims(img)
  pipe = Base64EncodePipe(io)
  for index in 1:768:length(img)
    m = index + 767 < length(img) ? "1" : "0"
    if index == 1
      write_kitty_image_escape_sequence(io, payload, index, pipe; f="32", s=width, v=height, m=m, controll_data...)
    else
      write_kitty_image_escape_sequence(io, payload, index, pipe; m=m)
    end
  end
end

function kitty_encode(io::IO, img::Array{TransparentColor}; controll_data...)
  kitty_encode(io, RGBA{N0f8}.(img); controll_data...)
end

function kitty_encode(io::IO, img::Array{RGBA{N0f8}}; controll_data...)
  height, width = string.(size(img))
  payload = permutedims(img)
  write_kitty_image_escape_sequence(io, payload; f="32", s=width, v=height, controll_data...)
end

function kitty_encode_compressed(io::IO, img::Array{TransparentColor}; controll_data...)
  kitty_encode_compressed(io, RGBA{N0f8}.(img); controll_data...)
end

function kitty_encode_compressed(io::IO, img::Array{RGBA{N0f8}}; controll_data...)
  height, width = string.(size(img))
  payload = permutedims(img)
  write_kitty_image_escape_sequence_compressed(io, payload; f="32", s=width, v=height, o="z", controll_data...)
end

function kitty_encode_chunked_compressed(io::IO, img::Array{TransparentColor}; controll_data...)
  kitty_encode_chunked_compressed(io, RGBA{N0f8}.(img); controll_data...)
end

function kitty_encode_chunked_compressed(io::IO, img::Array{RGBA{N0f8}}; controll_data...)
  height, width = string.(size(img))
  payload = permutedims(img)

  # TODO: find a better way of doing this (if there is one)
  # also check if using red, green, blue, alpha is faster than converting to RGBA
  io1 = IOBuffer()
  buffer = Base64EncodePipe(io1)
  stream = ZlibCompressorStream(buffer)
  write(stream, payload)
  close(stream)
  close(buffer)

  partitions = Iterators.partition(take!(io1), 4096)
  for (i, chunk) in enumerate(partitions)
    m = i < length(partitions) ? "1" : "0"
    if i == 1
      write_kitty_image_escape_sequence_raw(io, chunk; f="32", s=width, v=height, m=m, o="z", controll_data...)
    else
      write_kitty_image_escape_sequence_raw(io, chunk; m=m)
    end
  end
end





# values for control data: https://sw.kovidgoyal.net/kitty/graphics-protocol.html#control-data-reference
function write_kitty_header(io::IO, controll_data...)
    write(io, b"\033_G")
    first_iteration = true
    bytes = 0
    for (key, value) in controll_data
        if first_iteration
            first_iteration = false
        else
            bytes += write(io, ',')
        end
        bytes += write(io, key, '=', value)
    end
    return bytes + write(io, ';')
end

# Chunked data
function write_kitty_image_escape_sequence(io::IO, payload::Array{<:Colorant{N0f8, N}}, index::Int, buffer; controll_data...) where N
    bytes = write_kitty_header(io, controll_data...)
    bytes += _write_64(io, payload, index, buffer)
    return bytes + write(io, b"\033\\")
end

# Non chunked data
function write_kitty_image_escape_sequence(io::IO, payload::Array{<:Colorant{N0f8, N}}; controll_data...) where N
    bytes = write_kitty_header(io, controll_data...)
    bytes += _write_64(io, payload)
    return bytes + write(io, b"\033\\")
end

function write_kitty_image_escape_sequence_compressed(io::IO, payload::Array{<:Colorant{N0f8, N}}; controll_data...) where N
    bytes = write_kitty_header(io, controll_data...)
    bytes += _write_64_compressed(io, payload)
    return bytes + write(io, b"\033\\")
end

function write_kitty_image_escape_sequence_raw(io::IO, payload; controll_data...) where N
    bytes = write_kitty_header(io, controll_data...)
    bytes += write(io, payload)
    return bytes + write(io, b"\033\\")
end





# This may become unnecessary if they implement it in Base
Base.isopen(::Base64EncodePipe) = true

function _write_64_compressed(io::IO, payload::Array{<:Union{RGB{N0f8}, RGBA{N0f8}}})
  pipe = Base64EncodePipe(io)
  stream = ZlibCompressorStream(pipe)
  write(stream, payload)
  close(stream)
  close(pipe)
  # TODO return the number of bytes written
  return 0
end

# Non transparent colors
function _write_64(io::IO, payload::Array{<:AbstractRGB{N0f8}}, index::Int, buffer::Vector{UInt8})
  len = min(length(payload) - index, 1023)
  i = 0
  for x in index:index+len
      color = payload[x]
      b1 = reinterpret(UInt8, red(color))
      b2 = reinterpret(UInt8, green(color))
      b3 = reinterpret(UInt8, blue(color))
      buffer[i+1] =  Base64.encode(b1 >> 2          )
      buffer[i+2] =  Base64.encode(b1 << 4 | b2 >> 4)
      buffer[i+3] =  Base64.encode(b2 << 2 | b3 >> 6)
      buffer[i+=4] = Base64.encode(          b3     )
  end
  return unsafe_write(io, pointer(buffer), i)
end

function _write_64(io::IO, payload::Array{<:AbstractRGB{N0f8}})
  X = min(512, length(payload))
  Y = cld(length(payload), X)
  buffer = Vector{UInt8}(undef, 4X)
  for y in 1:Y
      i = 0
      for x in 1:X
          color = payload[x,y]
          b1 = reinterpret(UInt8, red(color))
          b2 = reinterpret(UInt8, green(color))
          b3 = reinterpret(UInt8, blue(color))
          buffer[i+1] =  Base64.encode(b1 >> 2          )
          buffer[i+2] =  Base64.encode(b1 << 4 | b2 >> 4)
          buffer[i+3] =  Base64.encode(b2 << 2 | b3 >> 6)
          buffer[i+=4] = Base64.encode(          b3     )
      end
      unsafe_write(io, pointer(buffer), i)
  end
  return 4X * Y
end

function _write_64(io::IO, payload::AbstractMatrix{<:AbstractRGB{N0f8}})
  X, Y = size(payload)
  buffer = Vector{UInt8}(undef, 4X)
  for y in 1:Y
      i = 0
      for x in 1:X
          color = payload[x,y]
          b1 = reinterpret(UInt8, red(color))
          b2 = reinterpret(UInt8, green(color))
          b3 = reinterpret(UInt8, blue(color))
          buffer[i+1] =  Base64.encode(b1 >> 2          )
          buffer[i+2] =  Base64.encode(b1 << 4 | b2 >> 4)
          buffer[i+3] =  Base64.encode(b2 << 2 | b3 >> 6)
          buffer[i+=4] = Base64.encode(          b3     )
      end
      unsafe_write(io, pointer(buffer), i)
  end
  return 4X * Y
end

# Transparent colors
function _write_64(::IO, payload::Array{RGBA{N0f8}}, index::Int, buffer::Base64EncodePipe)
  len = min(length(payload) - index, 767)
  write(buffer, view(payload, index:index+len))
  if index + len >= length(payload)
    close(buffer)
  end
  return ceil(Int, (len+1) * 4/3)
end

function _write_64(io::IO, payload::Array{RGBA{N0f8}})
  pipe = Base64EncodePipe(io)
  write(pipe, payload)
  close(pipe)
  return ceil(Int, length(payload) * 4/3)
end
