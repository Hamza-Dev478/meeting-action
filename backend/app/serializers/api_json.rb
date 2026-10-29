# Hand-written JSON shapes for /api/v1. Fields are only ever added, never
# renamed or removed, so older installed mobile clients keep working.
module ApiJson
  module_function

  def user(user)
    {
      id: user.id,
      name: user.name,
      email: user.email,
      organization: { id: user.organization.id, name: user.organization.name }
    }
  end

  def meeting_summary(meeting)
    {
      id: meeting.id,
      title: meeting.title,
      notes_preview: meeting.notes.squish.truncate(140),
      author_name: meeting.author.name,
      created_at: meeting.created_at.iso8601
    }
  end

  def meeting_detail(meeting)
    meeting_summary(meeting).merge(notes: meeting.notes)
  end

  def generation(generation)
    return nil if generation.nil?

    {
      id: generation.id,
      status: generation.status,
      provider: generation.provider,
      model: generation.model,
      prompt_version: generation.prompt_version,
      suggestion_count: generation.suggestion_count,
      rejected_count: generation.rejected_count,
      error_code: generation.error_code,
      error_message: generation.error_message,
      started_at: generation.started_at.iso8601,
      finished_at: generation.finished_at&.iso8601
    }
  end

  def suggestion(suggestion)
    {
      id: suggestion.id,
      meeting_id: suggestion.meeting_id,
      status: suggestion.status,
      description: suggestion.description,
      owner: suggestion.owner,
      due_date: suggestion.due_date&.iso8601,
      source_quote: suggestion.source_quote
    }
  end

  def action_item(item)
    suggestion = item.suggestion
    {
      id: item.id,
      suggestion_id: item.suggestion_id,
      meeting: { id: item.meeting.id, title: item.meeting.title },
      description: item.description,
      owner: item.owner,
      due_date: item.due_date&.iso8601,
      source_quote: item.source_quote,
      edited: item.edited?,
      original: {
        description: suggestion.description,
        owner: suggestion.owner,
        due_date: suggestion.due_date&.iso8601
      },
      completed: item.completed?,
      completed_at: item.completed_at&.iso8601,
      accepted_by_name: item.accepted_by.name,
      created_at: item.created_at.iso8601
    }
  end
end
