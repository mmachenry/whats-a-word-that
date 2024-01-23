//import { useState } from 'react'
import TextField from '@mui/material/TextField'

interface IPatternProps {
  onChange (string): void;
}

export default function Pattern (props: IPatternProps) {
  const updateRegex = (event: React.ChangeEvent<HTMLInputElement>) => {
    const value = event.target.value
    props.onChange(value)
  }

  return (
    <TextField
      sx={{ width: 300 }}
      label="Regex"
      onChange={updateRegex}
    />
  )
}
