import { useState } from 'react'
import Autocomplete from '@mui/material/Autocomplete'
import TextField from '@mui/material/TextField'
import Button from '@mui/material/Button'
import axios from 'axios'

interface ICategorySelectProps {
  host: string;
  onChange (string): void;
}

export default function CategorySelect (props: ICategorySelectProps) {
  const [categories, setCategories] = useState<string[]>([])

  const onChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    props.onChange(event.target.value)
  }

  const onInputChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const value = event.target.value

    axios.get(
      "https://" + props.host
      + "/w/api.php?action=query"
      + "&list=allcategories"
      + "&acprefix=" + value
      + "&origin=*&format=json",
    ).then((result) => {
      const matched = result.data.query.allcategories.map(
        (item) => item["*"]
      )
      setCategories(matched)
    })
  }

  return (
    <>
      <Autocomplete
        onInputChange={onInputChange}
        onChange={onChange}
        options={categories}
        sx={{ width: 300 }}
        renderInput={
          (params) => <TextField {...params} label="Category" />
        }
      />
    </>
  )
}

