local M = {}

function M.save(pb)
  pb = pb or hs.pasteboard
  return pb.readAllData()
end

function M.restore(saved, pb)
  pb = pb or hs.pasteboard
  return pb.writeAllData(saved)
end

function M.read_plain(pb)
  pb = pb or hs.pasteboard
  return pb.readString()
end

function M.write_rich(rtf_bytes, plain_text, pb)
  pb = pb or hs.pasteboard
  return pb.writeAllData({
    ["public.rtf"] = rtf_bytes,
    ["public.utf8-plain-text"] = plain_text,
  })
end

function M.write_plain(plain_text, pb)
  pb = pb or hs.pasteboard
  return pb.writeAllData({
    ["public.utf8-plain-text"] = plain_text,
  })
end

return M
